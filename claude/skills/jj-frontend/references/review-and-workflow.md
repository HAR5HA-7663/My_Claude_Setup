# Review and workflow

## Contents
- Design first, then build
- Briefs are requirements
- The feature checklist (A to J)
- Parallel agents with disjoint ownership
- Reviewing a PR
- Shipping
- Keep skills true
- What annoys a demanding UI owner

## Design first, then build

1. **Prototype in a design tool first** (for example Claude Design): give it the needs, the product principles and the repo for context, and iterate until it looks right. Do not over-constrain it.
2. **Port with fidelity.** Port the prototype's layout, colour and density 1:1, mapping to tokens only where the values match. "Translating" a prototype into the existing shell loses what made it good. The exception: the prototype's table, picker or dropdown is still the house component. Fidelity in look, reuse in mechanics.
3. When porting from another product, the source app is a **behaviour** reference, not a visual one.
4. **UI first, backend second.** Build the full UI on a mock or JSON world, perfect it, then build the backend. Delete the mocks before the PR.
5. **Settle the domain model before building UI on it.** A surface rebuilt six times in five days because the model came last is the cautionary tale.
6. Show one instance before building the set (one dashboard board before ten).

## Briefs are requirements

- Short imperative prompts ("make it smooth", "go til done", "localhost it") are structural requirements, not suggestions. Every sentence counts.
- Scope follows the exact words. If the person names a surface, that is the scope. List what is out of scope rather than silently expanding.
- "Easy fix" or "one-shot it": skip the spec and plan and just do it. Big features: a written spec, then a plan, then small thematic commits.
- Push back when there is a better way, and say why.
- Think of a human using it and what they would expect.

## The feature checklist (A to J)

Every screen, every item required, every item measured:

- **A. Spacing and scaling.** Screenshots at 1280×800, 1440×900, 1920×1080, light and dark, compared with the design. No truncated titles, no overflow, no void, no horizontal scroll, nothing covered by a floating element. Bordered panes, in-pane scroll.
- **B. Componentization.** No repeated markup (the gate fails on a repeated class list). Screens are composition only (< 200 lines). One component per concept.
- **C. Motion.** Every open and close animates from the tokens: dialogs, sheets, popovers, dropdowns, rail toggles, tab switches, list add/remove, number changes, selection and hover, drag previews. Verified by frame sampling.
- **D. Editability.** Every rail and side pane is resizable with a persisted width, collapsible, with a reset. Lists of sections, widgets, cards or columns reorder by drag with persisted order. A Customize affordance exposes it all.
- **E. Configurability.** Every list of options is a registry; the person's choices persist with a reset. Saved views have names. Nothing a person would want to change is a JSX literal.
- **F. AI at the centre.** The AI mark on everything the assistant touched; an Ask affordance on every record, pane or row group that focuses the assistant; live AI activity visible.
- **G. Permissions.** Every action behind a permission key. No role literals.
- **H. Parity.** The behaviours the old product or the design has (the coverage list) are present, restyled to the system.
- **I. Copy.** No vendor or internal names, short labels, no em dashes, no explainer paragraphs.
- **J. Tests.** The screen renders without console errors at two widths; the main interactions; one motion sample; one preference persists across reload; the assistant focus hand-off.

## Parallel agents with disjoint ownership

- Build in waves: wave 1 builds the shared primitives (motion, components, companion); wave 2 is one agent per feature folder with the full A to J checklist; wave 3 integrates, runs the gates and specs, and does a visual pass.
- Each agent owns disjoint files, its own dev port and its own test database. Shared files belong to the integrator. An agent that needs a shared change writes the exact request in its report and uses the closest existing primitive meanwhile.
- For multi-role features, send one "user bot" per role to drive localhost as that persona and return ranked, concrete findings.
- Audit adversarially: a finder agent plus an independent verifier. Expect a share of findings to be wrong; verify each against the code before fixing.

## Reviewing a PR

The bar is "is this what we would build", not "does it work". UI findings hold the merge like functional ones.

1. **The PR body is a claim sheet, not evidence.** Re-run everything; treat unverified claims as false.
2. **Duplicate-artifact check.** For every file, helper, component or test the PR adds, look for an existing one it duplicates. A parallel copy leaves the original asserting old behaviour.
3. **Sibling-surface sweep.** When a shared helper or component changes, grep all its call sites: every consumer inherits the new behaviour, and copy and assumptions at other call sites go stale. Responsive layouts can render a component twice; check both.
4. **UI quality bar.** Drive every screen the PR adds or reshapes; screenshot 1440 light and dark and 390; read them against the layout and interaction rules (one-page fit, panes fill, commit actions pinned, drag where reordering exists, designed empty states, previews). Grep the diff for banned native controls and hand-rolled versions of shared components. The author's prototype is not the spec; the standard is.
5. **Verify in a separate worktree** (never in the shared checkout, never stash someone's work): check the merge for conflicts, do a real dependency install (never symlink `node_modules`: dev caches live inside it), run the whole touched feature's tests, lint the changed files, run the real build.
6. **CI triage:** compare the PR's failures with main's latest run; identical failures are pre-existing debt, but do not let them mask new ones. A "CI passed" notice is a claim: check the run status and timestamps yourself before merging.
7. **Decide.** Merge on your own only when verification is fully green, there are zero findings, every claim is verified, and nothing touches migrations, permissions, payments or messaging consent. Otherwise report findings with `file:line` and a concrete failure scenario, and hold.
8. **Merged is not deployed.** Confirm the deployment of that commit actually happened (some hosts silently skip deploys for unrecognised commit authors) by checking the commit status and the live build id.

## Shipping

- Small, path-limited, themed commits. The pre-push hook must pass; never `--no-verify`.
- Features can ship dark behind an opt-in flag, and "ships dark" must be literally true.
- Production data changes are the owner's call.

## Keep skills true

- The standards live in the repo as a skill tree that agents load before touching UI: the rules, the component roster, the traps and the proof recipe.
- When the code and a skill disagree, verify against the code and fix the skill in the same session. Stale skills are worse than none.
- Date new facts in the skill ("2026-09-22: modals resize smoothly"), so the next person knows when and why a rule appeared.

## What annoys a demanding UI owner

- "Done" with no evidence, or a summary that skips half the asks.
- Half transitions, and anything that snaps.
- A new component when one exists. Patchwork. Hardcoding.
- Dead whitespace, explainer text, extra CTAs.
- A side page or harness built for review instead of the real app on its usual port.
- Being slow on small things.
