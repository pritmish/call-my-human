#!/usr/bin/env bash
#
#  call-my-human — installer
#  Lets your coding agent phone you when it genuinely needs you.
#
#      curl -fsSL https://raw.githubusercontent.com/pritmish/call-my-human/main/install.sh | bash
#
#  Supports macOS, Linux and Windows (Git Bash / WSL),
#  with Claude Code and OpenAI Codex.
#
set -euo pipefail

# Each agent gets its own SKILL.md — same skill, written in that agent's own voice.
# Both land as SKILL.md in the agent's skills folder.
BASE_URL="${CMH_BASE_URL:-https://raw.githubusercontent.com/pritmish/call-my-human/main}"
CONF_DIR="${CMH_CONFIG_DIR:-$HOME/.call-my-human}"
API="https://api.smallest.ai/atoms/v1"
KEY_URL="https://app.smallest.ai/dashboard/api-keys"
PROMPT="hey, setup call-my-human skill"

# ── presentation ───────────────────────────────────────────────────────────
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ] && [ -z "${NO_COLOR:-}" ]; then
  B=$(printf '\033[1m'); D=$(printf '\033[2m'); G=$(printf '\033[32m')
  Y=$(printf '\033[33m'); R=$(printf '\033[31m'); X=$(printf '\033[0m')
else
  B=""; D=""; G=""; Y=""; R=""; X=""
fi
# Windows consoles are unreliable with UTF-8; fall back to ASCII marks.
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *UTF-8*|*utf8*|*UTF8*) OK="✓"; NO="✗"; AR="→" ;;
  *)                     OK="+"; NO="!"; AR="->" ;;
esac

ok()   { printf '  %s%s%s %s\n' "$G" "$OK" "$X" "$1"; }
warn() { printf '  %s%s%s %s\n' "$Y" "$NO" "$X" "$1"; }
die()  { printf '\n  %s%s%s %s\n\n' "$R" "$NO" "$X" "$1" >&2; exit 1; }
info() { printf '  %s\n' "$1"; }
dim()  { printf '  %s%s%s\n' "$D" "$1" "$X"; }
head_() { printf '\n%s%s%s\n' "$B" "$1" "$X"; }

# Read one line from the real terminal — under `curl | bash`, stdin is the script.
if { true < /dev/tty; } 2>/dev/null; then TTY=/dev/tty; else TTY=/dev/stdin; fi
# Prompts go to stderr: these run inside $( ) and stdout is the captured answer.
ask()    { printf '  %s' "$1" >&2; IFS= read -r  REPLY_ < "$TTY" || REPLY_=""; printf '%s' "$REPLY_"; }
asksec() { printf '  %s' "$1" >&2; IFS= read -rs REPLY_ < "$TTY" || REPLY_=""; printf '\n' >&2; printf '%s' "$REPLY_"; }

printf '\n%s  call-my-human%s\n' "$B" "$X"
dim "Let your coding agent phone you when it needs you."

# ── 1. platform ────────────────────────────────────────────────────────────
case "$(uname -s 2>/dev/null || echo unknown)" in
  Darwin)                      OS="macOS" ;;
  Linux)
    if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then OS="Windows (WSL)"
    else OS="Linux"; fi ;;
  MINGW*|MSYS*|CYGWIN*)        OS="Windows (Git Bash)" ;;
  *)                           OS="unknown" ;;
esac
[ "$OS" = "unknown" ] && die "Unsupported system. This installer needs macOS, Linux, or Windows via Git Bash or WSL."
command -v curl >/dev/null 2>&1 || die "curl is required but not installed."

head_ "1. System"
ok "$OS"

# ── 2. pick the coding agent ───────────────────────────────────────────────
head_ "2. Coding agent"

AGENTS=(); LABELS=(); DIRS=()
if command -v claude >/dev/null 2>&1; then
  AGENTS+=("claude"); LABELS+=("Claude Code")
  DIRS+=("${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/call-my-human")
fi
if command -v codex >/dev/null 2>&1; then
  AGENTS+=("codex");  LABELS+=("OpenAI Codex")
  DIRS+=("${CODEX_HOME:-$HOME/.codex}/skills/call-my-human")
fi

if [ ${#AGENTS[@]} -eq 0 ]; then
  warn "Neither Claude Code nor OpenAI Codex is installed."
  printf '\n'
  info "Install one, then run this again:"
  dim "Claude Code   https://claude.com/claude-code"
  dim "OpenAI Codex  https://developers.openai.com/codex"
  printf '\n'
  exit 1
fi

N=${#AGENTS[@]}
SEL=""                                   # space-separated indices, bash 3.2 friendly
if [ "$N" -eq 1 ]; then
  SEL="0"
  ok "${LABELS[0]} found"
else
  ok "You have both — which should get the skill?"
  printf '\n'
  i=0; while [ $i -lt $N ]; do printf '     %s) %s\n' "$((i+1))" "${LABELS[$i]}"; i=$((i+1)); done
  printf '     %s) Both\n' "$((N+1))"
  printf '\n'
  BOTH=$((N+1))
  for _ in 1 2 3; do        # bounded: never spin if the input stream is closed
    CHOICE=$(ask "Choose 1-$BOTH [$BOTH]: "); CHOICE="${CHOICE:-$BOTH}"
    if [ "$CHOICE" -ge 1 ] 2>/dev/null && [ "$CHOICE" -le "$BOTH" ] 2>/dev/null; then
      if [ "$CHOICE" -eq "$BOTH" ]; then
        i=0; while [ $i -lt $N ]; do SEL="$SEL $i"; i=$((i+1)); done
      else
        SEL="$((CHOICE-1))"
      fi
      break
    fi
    warn "Enter a number between 1 and $BOTH."
  done
  [ -n "$SEL" ] || die "No valid choice given."
fi

# The one we hand over to at the end, and whose config the other shares.
PRIMARY=$(set -- $SEL; echo "$1")
AGENT="${AGENTS[$PRIMARY]}"; AGENT_LABEL="${LABELS[$PRIMARY]}"

# ── 3. the skill ───────────────────────────────────────────────────────────
head_ "3. Skill"
# SKILL.md is loaded on every use, so the rare-path material — setup, the wrapper
# prompt, the API reference — lives beside it in SETUP.md and is read only when needed.
for i in $SEL; do
  A="${AGENTS[$i]}"; DEST="${DIRS[$i]}"
  mkdir -p "$DEST"
  for FILE in SKILL.md SETUP.md; do
    URL="$BASE_URL/$A/$FILE"
    TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
    # Cache-busting headers so an update is always picked up.
    if curl -fsSL -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' "$URL" -o "$TMP" 2>/dev/null \
       && [ -s "$TMP" ]; then
      mv "$TMP" "$DEST/$FILE"; trap - EXIT
    else
      die "Could not download $FILE from:
      $URL
      Check your connection and try again."
    fi
  done
  ok "${LABELS[$i]}"
  dim "$DEST/"
done

# ── 4. the API key ─────────────────────────────────────────────────────────
head_ "4. smallest.ai API key"
mkdir -p "$CONF_DIR"; chmod 700 "$CONF_DIR" 2>/dev/null || true

if [ -s "$CONF_DIR/apikey" ]; then
  ok "Already saved — leaving it alone"
  dim "Delete $CONF_DIR/apikey to change it."
else
  info "This is what lets the agent place calls. It stays on this machine,"
  info "and your coding agent never sees the value."
  printf '\n'
  dim "Get one (free to start): $KEY_URL"
  printf '\n'
  # Required: a working key or nothing is set up. Never fall through without one.
  SAVED=""
  for attempt in 1 2 3; do
    KEY=$(asksec "Paste your API key (hidden): ")
    if [ -z "$KEY" ]; then
      warn "The key is required — nothing works without it."
      continue
    fi
    printf '  checking... '
    CODE=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $KEY" "$API/agent" 2>/dev/null || echo 000)
    case "$CODE" in
      200) printf '%sworks%s\n' "$G" "$X"
           printf '%s' "$KEY" > "$CONF_DIR/apikey"; chmod 600 "$CONF_DIR/apikey"; unset KEY
           ok "Saved to $CONF_DIR/apikey"; SAVED=1; break ;;
      000) printf '%sno response%s\n' "$R" "$X"; warn "Could not reach smallest.ai. Check your connection." ;;
      *)   printf '%srejected%s\n' "$R" "$X"
           warn "smallest.ai did not accept that key. Copy it again from:"
           dim "$KEY_URL" ;;
    esac
  done
  [ -n "$SAVED" ] || die "No working API key, so setup stopped here.
      Get one at $KEY_URL and run this installer again."
fi

# ── 5. hand over ───────────────────────────────────────────────────────────
head_ "5. One last step"
# Deliberately not launching the agent. These are full-screen TUIs, and starting one
# from inside an installer — especially under `curl | bash`, where stdin is the script —
# leaves it without a usable terminal. Printing the command is boring and always works.
info "Open $AGENT_LABEL and say:"
printf '\n      %s%s%s\n\n' "$B" "$PROMPT" "$X"
info "It will ask for your phone number, then offer a test call."
if [ "$(set -- $SEL; echo $#)" -gt 1 ]; then
  info "Doing it once covers both agents — they share the same settings."
fi
printf '\n'
