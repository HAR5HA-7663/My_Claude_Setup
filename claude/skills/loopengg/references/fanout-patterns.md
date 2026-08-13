# Fan-out Patterns — Choosing and Shaping the Fleet

Read when deciding *how* to dispatch, not just *what tier*.

## Contents

- [Agent tool vs Workflow](#agent-tool-vs-workflow)
- [Pipeline by default](#pipeline-by-default)
- [Standard fleet shapes](#standard-fleet-shapes)
- [Quality patterns](#quality-patterns)
- [Collision rules](#collision-rules)
- [Prompting a worker](#prompting-a-worker)

## Agent tool vs Workflow

| Situation | Use |
|---|---|
| 1-4 independent tasks, no ordering between them | **Agent tool**, several calls in one message so they run concurrently |
| Continuing a worker that already has context | **SendMessage** to its ID/name — not a fresh Agent call |
| Work-list of 5+ items, or multi-stage (find → verify → synthesize) | **Workflow** — deterministic control flow, cached resume, one progress tree |
| Loop until a condition (until dry, until count, until budget) | **Workflow** — the loop lives in the script, not in your head |
| Need the conclusion but not the file dumps | **Agent** / `Explore` — output stays out of your context |

Hybrid is usually right: scout inline to discover the work-list, then hand the
list to a Workflow to pipeline over. You do not need to know the shape before
the *task* — only before the *orchestration step*.

Chain several single-phase workflows across turns (understand → design →
implement → review) rather than one giant script. Read each result before
deciding the next phase; that keeps the user in the loop at phase boundaries,
which is exactly where this mode reports.

## Pipeline by default

`pipeline(items, stage1, stage2, ...)` runs each item through all stages
independently — item A can be in stage 3 while item B is still in stage 1.
Wall-clock is the slowest single chain, not the sum of slowest-per-stage.

`parallel(thunks)` is a **barrier** — it waits for everything. Only justified
when stage N genuinely needs cross-item context from all of stage N-1:

- dedup/merge across the full result set before expensive downstream work
- early-exit on a total ("0 findings → skip verification entirely")
- a prompt that references "the other findings" for comparison

Not justified by "I need to flatten/map/filter first" (do it inside a stage) or
"the stages are conceptually separate" (that is what pipeline models).

Both `parallel` and `pipeline` resolve failures to `null` — `.filter(Boolean)`
before using results.

## Standard fleet shapes

**Review / audit** — dimensions → find → adversarially verify → synthesize.
Per-dimension finders (sonnet gathering, opus where judgment is needed), 1-2
opus skeptics per finding, one opus synthesizer.

**Migration / sweep** — scout the sites inline, then pipeline: transform each
(sonnet, `isolation: 'worktree'` only if workers mutate the same files) →
verify each (sonnet build/test gate) → one opus pass over the failures.

**Research** — multi-modal sweep (each agent searches a *different* way: by
container, by content, by entity, by time) → deep-read the hits → opus
synthesis. Diversity of search angle beats N identical searchers.

**Design / decision** — N independent attempts from different angles → parallel
judges → synthesize from the winner, grafting the best ideas from runners-up.
Beats one-attempt-iterated when the solution space is wide.

**Implement from a plan** — partition by file, one sonnet worker per partition,
one sonnet build/test gate after, one opus reviewer over the combined diff.

## Quality patterns

- **Adversarial verify** — prompt the skeptic to *refute*, defaulting to
  "refuted" under uncertainty. Kill the finding if the majority refutes.
- **Perspective-diverse verify** — when a finding can fail in more than one way,
  give each verifier a distinct lens (correctness, security, does-it-reproduce)
  instead of N identical refuters.
- **Loop-until-dry** — for unknown-size discovery, keep spawning finders until K
  consecutive rounds return nothing new. Dedup against everything *seen*, not
  against everything *confirmed*, or judge-rejected items reappear forever and
  the loop never converges.
- **Completeness critic** — a final agent asking "what is missing — a modality
  not run, a claim unverified, a source unread?" Its answer is the next round.

## Collision rules

- **`agent-browser` is a singleton.** One browser worker at a time, ever. Queue
  browser QA steps and run them sequentially from one dedicated tester slot.
- **Partition writers by file.** Two workers must never hold the same file. If
  the split is not clean, serialize them or do it inline.
- **`isolation: 'worktree'`** only when parallel writers would genuinely
  conflict — it costs setup time and disk per agent.
- **Shared branch discipline** is the project's call, not this skill's. If the
  repo pins everyone to one branch, no worker may create, switch, stash, or
  reset — that yanks the tree out from under every other worker mid-edit.

## Prompting a worker

A worker sees none of this conversation. Give it, explicitly:

1. **The goal** in one sentence, and what "done" means.
2. **The exact scope** — file paths, the work item, what it must not touch.
3. **The return shape** — its final text *is* the return value. For structured
   data, use the Workflow `schema` option so validation happens at the tool
   layer and the model retries on mismatch, instead of asking for JSON in prose.
4. **The verification it must run itself** — the command, and that it must paste
   real output, not a summary of it.

Never accept a worker's "done, all tests pass" without the output. Claims from
subagents are unverified until independently checked — that is what step 4 of
the loop is for.
