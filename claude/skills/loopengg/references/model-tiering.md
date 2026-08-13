# Model Tiering — Mechanics and Cost Discipline

Read before authoring a Workflow script or any fan-out larger than ~4 agents.

## Contents

- [The one rule](#the-one-rule)
- [The tiers](#the-tiers)
- [Setting the model](#setting-the-model)
- [Effort tracks tier](#effort-tracks-tier)
- [Fleet sizing](#fleet-sizing)
- [Anti-patterns](#anti-patterns)

## The one rule

> Every spawned agent gets an EXPLICITLY chosen model tier, picked from the
> task. Never let a fleet inherit the top model by default. Default to the
> CHEAPEST tier that can do the job, and escalate only with a reason.

Origin: on 2026-07-08 a large fleet was fanned out with every agent inheriting
the top model — pollers, file moves, status flips, code edits, reviews, all on
the top tier. It maxed out two 20x accounts in one day.

If you are about to spawn 10+ agents and none of the calls carries a `model:`,
stop — that is the exact pattern.

## The tiers

| Tier | Model | Use for | Mindset |
|---|---|---|---|
| **Track** | `haiku` | Pollers and watchers (CI/deploy waits, run-status loops), status flips, file moves, log tailing, "wait until X then report", any mechanical loop with **zero judgment** | Cheapest. If it never makes a decision, it is haiku. |
| **Execute** | `sonnet` | Scoped implementation from a clear spec, scripted single steps (open a PR with a written body, scripted browser QA, post a comment with provided content), running a defined build/test gate and reporting, straightforward edits following an unambiguous instruction | Fast. If the *what* is decided and only the *doing* remains, it is sonnet. **Default for execution work.** |
| **Think** | `opus` | Root-causing, architecture and planning, adversarial verification, code review, synthesis across many inputs, security analysis, resolving genuine ambiguity, anything where a wrong call is expensive | Reserved for judgment. If the task requires *deciding*, it is opus. |

**`fable` belongs to the orchestrator only** — the single agent holding the
thread, deciding, and synthesizing. That one coordinating brain is where the top
model earns its cost. Never pass `model: 'fable'` to a fanned-out worker; their
thinking tier is `opus`.

## Setting the model

**Agent tool** — set `model` on every call, or use a pinned agent type:

```
Agent({ subagent_type: 'general-purpose', model: 'sonnet', ... })   // execution
Agent({ subagent_type: 'general-purpose', model: 'opus',   ... })   // judgment
Agent({ subagent_type: 'poller',                           ... })   // pinned haiku
Agent({ subagent_type: 'scripted-runner',                  ... })   // pinned sonnet
Agent({ subagent_type: 'Explore',          model: 'sonnet', ... })  // read-only sweep
```

Prefer `poller` and `scripted-runner` over raw `model:` overrides — they carry
safety rules baked into their definitions. Custom agent types keep their
frontmatter model; a `model` override is ignored on `subagent_type: 'fork'`
(forks always inherit the parent).

**Workflow `agent()`** — same rule, per stage:

```js
agent(prompt, { model: 'haiku',  effort: 'low'  })   // poll / track stage
agent(prompt, { model: 'sonnet'                  })   // implement / mechanical-verify stage
agent(prompt, { model: 'opus',   effort: 'high' })    // judge / adversarial-verify stage
```

Add `model` to the matching entry in `meta.phases` when a phase pins a specific
model, so the progress display is honest about what is running.

## Effort tracks tier

- `effort: 'low'` — every haiku/mechanical stage, always.
- default — sonnet execution stages.
- `effort: 'high'` or `'xhigh'` — only the hardest opus verify/judge stages.

Never pair a high effort with a mechanical loop; it is pure waste.

## Fleet sizing

- **Scale the fleet to the task.** "find a bug" → a few finders. "thoroughly
  audit" → a larger but **tiered** pool, not 30 top-tier clones.
- **Default ceiling is 12 workers per fan-out** (this mode's cap). Longer
  work-lists pipeline through a bounded pool instead of one-agent-per-item.
- **A typical review fleet** = per-dimension finders (sonnet for gathering,
  opus for the dimensions needing judgment) + opus verifiers (1-2 per finding)
  + one opus synthesizer + haiku for any build/deploy watcher.
- **Spend the expensive tier where it pays** — adversarial verification and
  final synthesis get opus, but bounded.
- **Watchers are always haiku.** A tracker that polls for 20 minutes must never
  sit on a thinking model.
- If the turn carries a token budget (`+500k`-style, readable as `budget.total`
  inside a Workflow script), tier down harder and cap fleet size rather than
  letting depth default upward.

## Anti-patterns

| Anti-pattern | Why it burns |
|---|---|
| Fan out N workers, all inheriting the top model | The two-account burn. The single worst one. |
| `model: 'opus'` on a file-move or status-flip agent | Pays thinking rates for zero decisions. |
| `effort: 'high'` on a polling loop | Multiplies the waste over every tick. |
| Spawning an agent for a two-line edit | Setup cost exceeds the work. Do it inline. |
| 5 skeptics per finding "to be safe" | Diminishing returns past 2-3. Bound it. |
| opus agents doing grep/find sweeps | Reads are cheap work — `Explore` or sonnet. |
| Forking mid-fleet without thinking | A fork inherits the top model silently. |
