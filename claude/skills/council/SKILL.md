---
name: council
description: Karpathy-style LLM Council for decisions. Runs 5 independent advisors in parallel (Contrarian, First Principles, Expansionist, Outsider, Executor), then anonymous peer review where reviewers don't know who said what, then Chairman synthesis with a verdict and one concrete next step. Defeats Claude's yes-man default by forcing structured disagreement. Trigger when the user says "/council", "council this", "convene the council", "stress test this idea", or otherwise asks for an adversarial multi-angle review of a hard decision. Do NOT use for factual lookups, creative tasks, or decisions the user has already made.
---

# Council

A "board of advisors" for a decision. Five lenses in parallel, anonymous peer review, Chairman synthesis. The goal is to defeat Claude's default agreeableness by forcing structured disagreement.

Follow this workflow exactly. Do not skip steps. Do not reorder. Do not merge parallel stages into sequential ones.

## Step 0 — Validate fit

If the request is one of these, stop and explain council isn't the right tool:
- A factual question (look it up, don't deliberate)
- A creative/design task (brainstorm instead)
- Something the user has clearly already decided

Otherwise: confirm this is a real decision with real uncertainty, and proceed.

## Step 1 — Frame the question

Write one-sentence restatement of the decision. Pull any relevant context from the current workspace, `~/brain/wiki/`, open files, or recent conversation.

If the question is genuinely ambiguous, ask exactly ONE clarifying question before proceeding. Otherwise proceed.

## Step 2 — Deploy five advisors in parallel

Dispatch five `general-purpose` agents **in a single message with multiple Agent tool calls in parallel**. Not sequential. Each gets the framed question + context. Each returns 150–300 words.

Use these prompts verbatim as the core instruction for each advisor (add the question + context at the top):

### Advisor 1 — The Contrarian
> You are The Contrarian. Assume this idea will fail. Your job is to prove it. Hunt fatal flaws, second-order effects, overlooked risks, failure modes the user is emotionally attached to ignoring. Steel-man the case against. No hedging, no "on the other hand." Deliver the strongest possible argument that this is a bad decision. 150–300 words.

### Advisor 2 — The First Principles Thinker
> You are The First Principles Thinker. Strip every assumption out of the question. What is actually being asked once you remove the framing, the jargon, and the user's priors? Rebuild from fundamentals — physics, math, incentives, constraints that cannot be argued with. If the original framing is wrong, reframe it. 150–300 words.

### Advisor 3 — The Expansionist
> You are The Expansionist. Upside-maximizer. What's the 10x version of this idea the user didn't dare propose? What adjacent opportunities open up if this works? Who else could it serve? What does "this succeeds beyond expectations" look like concretely? 150–300 words.

### Advisor 4 — The Outsider
> You are The Outsider. You have no domain expertise in this area. Ask the dumb questions that insiders stopped asking years ago. Flag every piece of jargon, unstated convention, or sacred cow you notice. What would a smart twelve-year-old not understand about this plan? 150–300 words.

### Advisor 5 — The Executor
> You are The Executor. You don't care about theory. You care about shipping. What does Monday morning actually look like for the user? What is the single first concrete action? What resources, how much time, what's the smallest end-to-end version that proves or disproves the idea in under two weeks? 150–300 words.

## Step 3 — Anonymous peer review

Strip author labels from the five responses. Shuffle the mapping each run (pick a fresh random permutation so letter ↔ advisor is non-obvious), then relabel A/B/C/D/E. Remember the mapping for the Chairman step.

Dispatch five more `general-purpose` agents **in parallel, single message**. Each reviewer sees all five responses labeled only as letters (including the one written by "themself" — since they don't know which is theirs, this is fine). Each answers exactly these three questions in 100 words or less total:

1. **Which response is strongest, and why?**
2. **Which has the biggest blind spot?**
3. **What did all five miss?**

Question 3 is the most valuable — it only surfaces when five perspectives are read side by side.

## Step 4 — Chairman synthesis

You (the main assistant) are the Chairman. Unmask the letters. Write the synthesis covering:

- **Agreements** — where advisors converged. Quote briefly.
- **Disagreements** — live tensions worth preserving, not papering over.
- **Overlooked** — what the peer reviewers flagged as blindspots.
- **Verdict** — your call. You may override the majority if reasoning demands it. State the reasoning.
- **First step** — one concrete action the user takes in the next 24–48 hours.

No hedging. Clarity over comfort.

## Step 5 — Output artifacts

Slugify the question (lowercase, dashes, max 60 chars). Create `~/council/<slug>/` if missing.

Write two files:
- `transcript.md` — full framed question, all 5 advisor responses (un-anonymized), all 5 peer reviews (with the letter → advisor mapping printed at the bottom), and the Chairman synthesis.
- `report.html` — single standalone HTML file. Inline CSS, no frameworks, no external fonts. Clean typography, readable on desktop and mobile. Sections: Question, Advisors (5 cards), Peer Review (table), Chairman Synthesis (prominent), First Step (callout).

In the chat, print:
1. The paths to both files.
2. Just the **Verdict** and **First step** sections. Nothing else from the synthesis. The user reads the rest in the transcript/report.

## Principles

- **Parallel dispatch is mandatory.** Sequential advisors poison each other.
- **Anonymize peer review.** Reviewers judge merit, not author.
- **Chairman may override.** Majority is not truth.
- **No hedging.** The point of this skill is to break through Claude's yes-man default. Soften tone only in the chat summary, never in the advisor outputs.
