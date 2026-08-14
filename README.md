# call-my-human

Let your coding agent phone you — an actual voice call to your actual phone — when it is genuinely blocked on a decision only you can make, when you asked to be called about a result, or when something is urgent enough that a line in the terminal is too slow.

The agent writes the briefing, a voice agent calls you and talks it through, and the transcript comes back so it can act on what you said.

Works with **Claude Code** and **OpenAI Codex**, on **macOS, Linux and Windows** (Git Bash or WSL). Built on [smallest.ai](https://smallest.ai) voice agents.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/pritmish/call-my-human/main/install.sh | bash
```

The installer looks for Claude Code and Codex on your machine. If you have one, it uses it. If you have both, it asks — either, or both — and installs the matching edition to each. Then it takes your smallest.ai API key (hidden, and verified before it saves) and hands over to your agent to finish: it asks for your phone number, then offers a test call.

Installing to both is worth doing — the settings live in one place, so setting up in one agent means the other works straight away.

You'll need a smallest.ai API key — [get one here](https://app.smallest.ai/dashboard/api-keys), free to start. Outbound calling reaches about two dozen countries.

## What gets installed

| Path | What |
|---|---|
| `~/.claude/skills/call-my-human/` | the skill (Claude Code) |
| `~/.codex/skills/call-my-human/` | the skill (Codex) |
| `~/.call-my-human/apikey` | your API key, `0600`, never read into the agent's context |
| `~/.call-my-human/config.json` | agent id, your number, timezone — no secrets |

Setup also creates **one reusable voice agent** on your smallest.ai account. Leave it there; every call reuses it.

## Turning it off

```bash
rm -rf ~/.call-my-human
```

That removes the key and the config, and revokes the ability to call you. To rotate the key instead, just overwrite `~/.call-my-human/apikey`.

## Repo layout

```
claude/SKILL.md    Claude Code edition — loaded every time the skill runs
claude/SETUP.md    first-run setup, wrapper prompt, API reference — read on demand
codex/SKILL.md     same, in Codex's voice
codex/SETUP.md     same, in Codex's voice
install.sh         picks the agent(s), installs both files for each
```

`SKILL.md` is in context on every use, so it holds only what a call needs. Setup and the API details live in `SETUP.md` beside it and are read on demand.

The Claude and Codex editions are the same skill and differ only in which agent is speaking. If you change one, make the same change in the other.

## Making it sound right

The phone manner lives in the wrapper prompt inside `SETUP.md`. If a call felt too fast, too formal or too chatty, just tell your agent — `SETUP.md` has a section on routing feedback to the right layer, whether that's the wrapper, the voice settings, or the skill file itself.
