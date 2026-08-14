---
name: call-my-human
description: Place a real outbound phone call to the user and return the transcript, using a smallest.ai voice agent. Use when a long-running or unattended task is blocked on a decision only the user can make, when they asked to be called about a result ("call me when the deploy passes"), or when something urgent enough surfaces that waiting for them to read the terminal is too slow. Also use to set up, test, or retune that calling ability. Do not use for questions answerable by reading code, for routine progress updates, or while the user is actively at the keyboard.
---

# Call my human

Prompt a voice agent, have it phone the user's real number and speak as you, then read back
the transcript. Use it like calling a colleague at their desk: sometimes exactly right,
usually unnecessary.

**Config:** `~/.call-my-human/config.json` · **Base:** `https://api.smallest.ai/atoms/v1` · **Auth:** `Authorization: Bearer sk_...` · **Needs:** `python3` and `curl`

> API details here were verified against the Atoms OpenAPI spec and route handlers. Where
> the public docs disagree, the API reference in `SETUP.md` is correct —
> follow them rather than re-deriving from docs.smallest.ai.

## Route the request

| Situation | Go to |
|---|---|
| Asked to set this up, or `~/.call-my-human/config.json` is missing | **`SETUP.md`** — check what already exists first; never attempt it alone |
| Considering a call | [Decide whether to call](#decide-whether-to-call) |
| Decided to call | [Prompt the agent](#prompt-the-voice-agent) → [Dial](#dial) |
| Call ended, or never connected | [After the call](#after-the-call) |
| Something failed | [Troubleshooting](#troubleshooting) |
| User gives feedback on a call | **`SETUP.md`** — fix it in the layer it came from |

## Decide whether to call

When a call is warranted, make it — that is the whole point of having this. The rest of
this section is how to tell warranted from not, so that the calls you do make land well.

**First, check they are not already reachable.** If the user is at the keyboard — they sent
a message recently, or the task was just handed over — ask in the terminal instead. Calling
is for sessions running unattended: long builds, migrations, scheduled runs, anything where
nobody is watching the output.

Then require **all** of:

1. Something needs deciding by a human, or needs hearing now.
2. More work — searching, reading, trying — will not answer it.
3. Getting it wrong or getting it late actually costs something.
4. Waiting for them to read the output is materially too slow.

Call:

- They asked to be called ("ring me when the migration finishes"). Honour it, good news or bad.
- Two valid approaches, both expensive to undo, and the choice is genuinely theirs.
- Something irreversible is next and the instructions are ambiguous.
- Something alarming surfaced — leaked credentials, production data at risk.
- One question has stalled the whole task for a long stretch.

Do not call:

- Reading more code would answer it. Read the code.
- A default is obvious. Take it, say so, move on.
- Wanting reassurance or permission to continue. Continue.
- Nearly done and it can wait for the summary.
- Already called about this. One call per thing.
- Progress updates or "I finished", unless they asked.

**When in doubt, do not call.** Write it in the output and keep working on everything that
does not depend on the answer. A ringing phone is a real interruption; a paragraph in the
terminal is not.

### Know what time it is for them

Check their local time before dialling — the config holds their `timezone`, and this
session may be running somewhere else entirely:

```bash
TZ=<timezone from config> date "+%H:%M %A"
```

This is context for the judgement, not a rule. Late at night raises the bar: something
worth a call at 3pm often isn't worth one at 1am, and can wait for the morning. But if they
asked to be called when the deploy finishes and it finishes at 2am, call them — they set
that expectation and they may well be awake for it. Weigh the hour against how much this
call actually matters to them, and decide.

## Prompt the voice agent

**This determines whether the call is any good.** The agent speaks as you, on a phone, with
no memory, no tools, and no access to the task. One free-text variable is its entire world
— no schema, no fields.

It already knows the universal things: that it is Codex, that turns run two or three
sentences, that it must not read out file paths or invent anything, that it hangs up when
done. Do not restate those. Spend the prompt on what is specific to this call:

- **How to open** — you write the actual first sentence separately (see [Dial](#dial)); here, say what the call should do straight after it.
- **What you were doing** — enough context, in plain speech, to orient them.
- **What the call is for** — a decision, a warning, a result, a confirmation.
- **If a decision** — the real options and the actual trade-off. Two is ideal; more than three does not survive a phone call. Say what was already ruled out so they do not re-suggest it.
- **What a finished call looks like** — what to walk away with.
- **What to do if they are unsure, or it is a bad time** — a default, so the call ends cleanly instead of stalling.

Treat that as a checklist of what tends to matter, not a form to fill in. Write the prompt
however this particular call needs to be written — one paragraph or six, in whatever order
makes it land. You are the only one holding the full context of the task, and none of it
reaches the agent except through this text, so the real job is deciding what the human
actually needs to hear and what they can be spared.

Anticipate the call, too. They will ask something back — work out what, and put the answer
in. A prompt that survives one follow-up question is worth far more than a tidy one.

Format it as markdown. Short headings for the situation, the options, what you need back —
the agent reads this as its instructions, never aloud, so structure helps it find the right
thing while the conversation is moving. That is separate from how it talks: the sentences
inside those sections still have to sound like speech, and it must never read a heading or
a list out to the human.

Write it to be *spoken*. No file paths, no code, no bullet lists, no jargon they would have
to decode by ear. "The checkout flow's retry logic", not `apps/api/src/checkout/retry.ts`.

The two examples below are deliberately short, just to show how differently a blocker and
good news open. Real prompts are usually longer and carry more context. Match the length to
the call, never to these.

A blocker:

> You are calling Priya. Open by telling her you are twenty minutes into the payment retry
> work she asked for and have hit a fork you cannot call yourself. The retry logic needs to
> know what to do when a card is declined for insufficient funds specifically. Option one
> is retrying once an hour later — recovers maybe a third of them, risks annoying customers
> with a repeat decline. Option two is not retrying and emailing them to update their card
> — safer, recovers fewer. Tell her you already ruled out retrying immediately, because the
> bank almost always declines again within the hour. Ask which she wants. If she is unsure,
> say you will go with the email since it cannot annoy anyone and she can change it later,
> then end the call.

News they asked for opens the other way round — lead with the result, not the context:

> You are calling Priya because she asked you to ring the moment the production migration
> finished. Open warmly and lead with it: done, four hundred thousand rows, about eleven
> minutes, no errors. Checkout is back up and the smoke tests passed. Ask whether she wants
> monitoring kept up for an hour or stopped here, take either answer, confirm it back in one
> sentence and let her go.

Bad: "Need a decision on retry logic in checkout.ts:142. Options: A) backoff B) no retry."
Unspeakable, no opening, no context, no default.

Read it back as if you were the one answering the phone. If it takes more than two sentences
to make clear why you rang, tighten the opening — then make the call.

## Dial

Write two plain text files first — never inline either as a shell argument, and never
hand-escape them into JSON:

- `/tmp/call-opening.txt` — **the single sentence spoken the moment they pick up.** This is literally the first thing they hear, so make it carry who is calling and why. It is the one part of the call you cannot leave to the agent.
- `/tmp/call-prompt.txt` — the full markdown briefing from the section above.

Then run this; it dials, logs the call, waits for it to end, and prints the transcript.

```bash
python3 - ~/.call-my-human /tmp/call-opening.txt /tmp/call-prompt.txt "short reason for the log" <<'PY'
import json, os, sys, time, urllib.error, urllib.request
home, ofile, pfile, reason = os.path.expanduser(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
c = json.load(open(os.path.join(home, "config.json")))
key = open(os.path.join(home, "apikey")).read().strip()   # never print this
B = "https://api.smallest.ai/atoms/v1"
H = {"Authorization": "Bearer " + key, "Content-Type": "application/json"}

def api(path, body=None):
    req = urllib.request.Request(B + path, json.dumps(body).encode() if body else None, H)
    try:
        return json.loads(urllib.request.urlopen(req, timeout=30).read().decode(), strict=False)["data"]
    except urllib.error.HTTPError as e:
        sys.exit("API %s on %s: %s\nSee the Troubleshooting table in the skill."
                 % (e.code, path, e.read().decode("utf-8", "replace")[:300]))

opening = open(ofile).read().strip()
# Both variables are required. An unset one is spoken aloud as literal "{{opening}}".
assert opening and "{{" not in opening, "opening must be one real spoken sentence"
body = {"agentId": c["agentId"], "phoneNumber": c["phoneNumber"],
        "variables": {"opening": opening, "prompt": open(pfile).read()}}
if c.get("fromProductId"):
    body["fromProductId"] = c["fromProductId"]
cid = api("/conversation/outbound", body)["conversationId"]
with open(os.path.join(home, "calls.log"), "a") as log:
    log.write("%s %s %s\n" % (time.strftime("%Y-%m-%dT%H:%M:%S"), cid, reason))
print("dialling %s (%s)" % (c["phoneNumber"], cid), flush=True)

v = {}
for _ in range(120):                      # 10 minutes
    time.sleep(5)
    v = api("/conversation/" + cid)
    if v.get("status") in ("completed", "no_answer", "failed", "cancelled", "blocked"):
        break
print("STATUS: %s  DURATION: %ss" % (v.get("status"), v.get("duration")))
for t in v.get("transcript") or []:
    who = "CLAUDE" if t.get("role") == "agent" else "HUMAN "
    if (t.get("content") or "").strip():
        print("%s: %s" % (who, t["content"].strip()))
PY
```

To re-check a call later, run the same block with the polling loop only, or
`GET /conversation/<conversationId>`.

## After the call

Act on what they said. If it was ambiguous, do not call back — take the best reading, say
which reading was taken, and flag it.

When the call does not connect — `no_answer`, `failed`, `blocked`, `cancelled` — do not
redial or retry in a loop. What happens next depends on why you rang:

- **You rang to get something decided.** Stop and hand it back. Do not pick an answer and carry on: the reason you rang is that this was not yours to guess, and a missed call does not change that. Put the question in your normal terminal output exactly as you would have if this skill did not exist, say that you tried to reach them by phone, and carry on with any part of the task that does not depend on the answer.
- **You rang to tell them something.** Nothing is blocked. Continue, and leave the news in your output so they have it when they are back.

**Still running after 10 minutes** — re-poll rather than placing a second call.

Report back in the session whatever the outcome: that a call was placed and why, what was
decided, and what changes as a result. A call whose effect the user never sees reads as an
interruption for nothing.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `500` with `Error in verifying token` | Bad or revoked API key — **not** an outage. Have them rewrite `~/.call-my-human/apikey` from app.smallest.ai/dashboard/api-keys. |
| `FileNotFoundError: .../apikey` | Setup step 1 was skipped, or the key was pasted into the chat instead of written to disk. Have them run the `read -rs` command. |
| `400 Invalid phone number` | Wrong format or unsupported country. Needs E.164 (`+14155551234`); outbound reaches ~two dozen countries. |
| `400` on outbound, mentions variables | A `variables` value was not a string, number, or boolean. Nested objects are rejected. |
| Transcript comes back with `[FIRSTNAME_1]` or similar placeholders | PII redaction is on — it defaults to on and masks the very content you called to collect. Turn it off: `redactionConfig.isEnabled: false`, see `SETUP.md`. |
| Call connects, agent says nothing | Published but not yet live — publish is async. Poll `GET /agent/{id}/branches` until `headRevisionNumber` rises. |
| Agent literally says "open curly curly opening" | The `opening` variable was not passed, or was empty. Both `opening` and `prompt` are required on every call. |
| Agent opens with the wrong greeting every time | `firstMessage` was set to a fixed string instead of `{{opening}}`. Re-publish it as `{{opening}}`. |
| Prompt appears verbatim as `{{prompt}}` on the call | The wrapper lost its placeholder, or the outbound body used a different variable name. Both must be `prompt`. |
| `404 Cannot POST .../drafts` | Wrong API generation. Config goes through `branches`, not `drafts` — see the API reference. |
| `Config changes must be made through a branch draft` | Same cause: use `PUT /agent/{id}/branches/{branchId}/draft`, not `PATCH /agent/{id}`. |
| `A first message is required to publish this agent` | `firstMessage` was blank. It must be a non-empty string; use `{{opening}}`. |
| Call never dials, no error | Account has no credit, or no phone number attached. Check the dashboard. |

## Changing the setup

First run, or the user wants a different voice, number or wording? Everything for that —
the setup walkthrough, the wrapper prompt published onto the agent, and the Atoms API
reference — is in **`SETUP.md`, next to this file**.

**Open it only when one of those is actually happening.** Do not read it to get oriented,
to check what the skill can do, or before placing a call — everything a call needs is
already here. It sits in a separate file precisely so it stays out of context until the
rare moment it matters.

If `SETUP.md` is missing, the install was incomplete: re-run the installer from
https://github.com/pritmish/call-my-human rather than improvising the API calls.
