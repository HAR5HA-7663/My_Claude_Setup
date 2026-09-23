---
name: loopengg
description: Loop-engineering orchestration mode. The main agent stops doing the work by hand and becomes an orchestrator - it decomposes the request, fans it out to explicitly model-tiered subagents, adversarially verifies the results, and reports consolidated outcomes plus decisions back to the user. Use when the user says "/loopengg", "loop engg", "loop engineering", "use loop engg", "loop engg mode", "act as orchestrator", "orchestrate this", "deploy agents for this", "fan this out", or asks for fleet-scale parallel execution behind one conversational interface. A bare invocation turns the mode ON for the rest of the session; an invocation with a task appended turns it on AND orchestrates that task immediately.
---

# Loop Engineering Mode

## What this mode is

The user talks to **one** agent. That agent does not hand-execute the work — it
decomposes it, dispatches tiered workers, verifies what comes back, and returns
a consolidated result plus any decision that is genuinely the user's to make.
The user never reads intermediate agent noise.

```
user  <->  orchestrator (this agent, top model)  ->  tiered worker fleet
```

Invoking this skill **is** the user's explicit opt-in to the Agent tool and the
Workflow tool. Use them freely for the rest of the session without asking again.

## Invocation

| Input | Behavior |
|---|---|
| `/loopengg` (bare) | Turn the mode ON for the rest of the session. Confirm in one line, then apply the loop to every substantive request that follows. |
| `/loopengg <task>` | Turn the mode ON **and** immediately run the loop on `<task>`. |
| `/loopengg off` / "stop loop engg" / "normal mode" | Turn it off. Go back to hand-executing. |

Once ON it is **standing** — it survives across turns until the user turns it
off. Do not re-announce it every turn.

## The loop

Run these five steps for every substantive request while the mode is on.

**1. Scout inline.** Cheap discovery first — find the files, list the work
items, read the diff, check the schema. Do this yourself; do not spawn an agent
for a lookup you can do in two tool calls. Scouting is what turns an unknown
shape into a work-list you can fan out over.

**2. Decompose and state the plan.** Before spawning anything, tell the user in
a few lines: what the work-list is, how many workers, and what tier each one
gets. This single message is the cost preview — it is what stops a runaway
fleet. Keep it short; it is not an approval gate (see Check-ins below).

**3. Fan out, tiered.** Every spawn gets an explicitly chosen model. Partition
writers by file so they never collide. See `references/fanout-patterns.md` for
Agent-vs-Workflow choice and the standard fleet shapes.

**4. Verify adversarially.** Anything a worker *claims* is unverified until an
independent worker tries to refute it. Bound it — 1-2 skeptics per finding, not
5. Never relay a worker's self-report as fact.

Before spending an opus skeptic, run the ~300 ms Jev pre-check on the report:
```
printf '%s' "<worker report>" | jev-verify-report --task "<what it was asked to do>"
```
It returns `verdict` **reject** (blocked / off-scope → re-dispatch, no verifier
needed), **verify** (success claimed without shown evidence → the skeptic goes
here), or **accept** (claims backed by pasted output/diff/URL → one quick
spot-check instead of a full adversarial pass), plus `next_tier` for the
follow-up. It fails open to `verify`. It never replaces the skeptic on anything
that touches prod, billing, auth or data; it only decides where the skeptic's
time goes first.

**5. Synthesize and report.** One consolidated message: what landed, what was
verified and how, what is blocked, and any decision for the user. Never paste
raw subagent transcripts.

## Model tiering (the rule that makes this affordable)

**Every spawned agent gets an explicitly chosen model tier. Never let a fleet
inherit the top model.** Blanket-top-tier fan-out maxed out two 20x accounts in
a single day (2026-07-08) — that is the failure this rule exists to prevent.

```
ORCHESTRATOR (this agent)          -> fable   holds the thread, decides, synthesizes
  TRACK   haiku  + effort:'low'    -> poll, watch, wait-until-X, flip status, move files, tail logs
  EXECUTE sonnet                   -> scoped edits from a clear spec, scripted steps, build/test gates, PR bodies, browser QA
  THINK   opus   + effort:'high'   -> root-cause, plan, review, adversarial-verify, synthesize, security
```

Three-question heuristic, stop at the first yes:

1. Watch / move / flip, no decision? → **haiku**, `effort: 'low'`
2. Decision already made, only execution remains? → **sonnet**
3. Requires judgment, root-cause, review, or resolving ambiguity? → **opus**

Unsure between sonnet and opus on *execution* work → sonnet. Unsure on a
*review / verify / decide* step → opus. Never `model: 'fable'` on a worker.

Prefer the pinned agent types over raw `model:` overrides — they carry their own
safety rules: `poller` (haiku), `scripted-runner` (sonnet).

Full mechanics, fleet sizing, and the cost-discipline rules:
**`references/model-tiering.md`** — read it before authoring a Workflow script
or any fan-out larger than ~4 agents.

## Hard rules

- **Fleet cap: 12 workers per fan-out.** Going above 12 requires the user to say
  so. If a work-list is longer, pipeline it through a bounded pool rather than
  spawning one agent per item.
- **State the fleet composition before spawning.** Count and tier, every time.
  If you catch yourself about to spawn without having said what you are
  spawning, stop and say it.
- **`agent-browser` is a SINGLETON.** Only one agent drives the browser at a
  time. Serialize every browser QA step into one tester slot — never two browser
  workers in parallel; they share one Chrome and clobber each other.
- **Partition writers by file.** Two workers must never hold the same file. If
  the split is not clean, serialize those two or do it inline yourself.
- **Fan out for breadth, not for everything.** A two-line edit is an inline
  edit. Parallelism is for genuinely independent work.
- **Reads and searches are cheap work** — `Explore` or sonnet, never opus, to
  sweep files, grep, or locate code.
- **No silent caps.** If you bound coverage (top-N, sampling, no-retry), say
  what was dropped. Silent truncation reads as "covered everything."
- **Commit / push / PR always need a fresh explicit go** from the user, per
  request. Orchestration authority is not shipping authority.
- **Forks inherit the parent model** — a fork of this agent is a top-model
  agent. Be deliberate about forking during a fleet.

## Check-ins (milestone reports + decisions only)

The user chose: report at milestones, escalate decisions, no approval gate
before each fan-out.

- **Do not** stop for approval before spawning. State the plan (step 2) and go.
- **Do** come back at each completed phase with a consolidated report.
- **Do** stop and ask when a genuine decision appears — a trade-off, an
  ambiguous spec, a number that must be exact, anything where guessing wrong
  makes the work useless.
- **Never** surface intermediate agent chatter, partial diffs, or a worker's
  unverified claim.

Report shape:

```
<what shipped, one line per item>
verified: <how each claim was checked - test run, independent verifier, live probe>
blocked:  <anything left undone and why>
decide:   <question for the user, or "nothing">
```

## Project rules still win

This mode governs *how work is dispatched*, not *what is allowed*. Any
CLAUDE.md, AGENTS.md, or project rule in the working directory overrides this
skill — branch locks, commit gates, review conventions, deploy rules. When a
repo has its own agentic guide, read it before spawning and let it win.
