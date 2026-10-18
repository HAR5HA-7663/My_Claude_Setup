---
name: jj-frontend
description: Jawad's frontend craft standard (JJ) for building, porting and reviewing product UI in React and Tailwind apps. Every element is a reusable component (no siblings, no native select/date/confirm), every open and close animates both ways from motion tokens, controls are gated by permission keys never roles, user-tunable surfaces persist with a reset, workspace pages fill the viewport with no dead whitespace, loading/empty/error states never lie, copy is white-labeled with no em dashes or explainer paragraphs, tokens only with first-class dark mode, and done means proven by a source gate, measured motion and screenshots read as a designer. Use for any UI work - pages, components, modals, drawers, menus, tables, filters, forms, layouts, animations, dark mode, AI assistant surfaces - and when asked to make it smooth, polish the UI, match a design, follow Jawad's or JJ's rules, run a UI check, or review a PR's UI.
---

# JJ frontend: the craft standard

The look changes per product. These rules do not. A screen is done when it is what a demanding product designer would ship **and** you can prove it.

## Prime directive

- **Do the proper fix every time.** The difference between a quick fix and a proper fix is minimal in energy; do it right the first time. If you see a bug in one place, fix the shared owner so it is fixed everywhere. When a better mechanism exists, migrate everything to it; never leave two side by side.
- **Reuse fully; never build around.** Use the existing component, table or flow with all its modes. If it has a limit, fix the limit at the root.
- **Never silence a type error or lint rule to get green.** Never fabricate data.
- **Scope is the person's exact words.** Every sentence of a brief is a requirement. List what is out of scope instead of silently expanding. Push back, with reasons, when there is a better way.

## The rules

Read the matching reference before working in that area.

1. **Every element is a component.** Name it on first use, even a one-off. Find the existing owner before writing markup; if one nearly fits, add a variant. A duplicate of a shared control is a review-blocking defect. Banned: `<select>`, `<datalist>`, `<input type=date|time|color>`, `window.confirm`/`alert`, `<details>` in overlays. → [components](references/components.md)
2. **Every transition is smooth and complete, open AND close.** enter → usable → exit → removed; reopen during exit works. Never `{cond && <Thing/>}` for anything visible. Nothing teleports or resizes suddenly, first load included. Timing from tokens (control 160, surface 220, panel 280, collapse 240 ms), never a literal or `transition-all`. Reduced motion shows and dismisses instantly. Prove it by sampling frames. → [motion](references/motion.md)
3. **Permissions, never roles.** `useCan(key)`, never `role === 'admin'`. A control the person cannot use is absent, or disabled with the reason. → [interaction](references/interaction.md)
4. **Configurable over hardcoded, with a reset.** Registries plus persisted per-user prefs (nav, filters, saved views, columns, sort, pane sizes, widgets, density), each with a reset and a "reset all". Explicit over automatic: never act silently for the person. → [interaction](references/interaction.md)
5. **Fill the page; kill dead whitespace.** Workspace screens hold the whole job in one viewport: fixed chrome, every unbounded region scrolling in its own pane, an unbroken `min-h-0` chain, commit actions never below unbounded content. Every page ends at the bottom of the screen in every state. No arbitrary `max-h-[300px]` boxes. One standard header bar. Stable buttons. Alignment measured, not eyeballed. → [layout](references/layout.md)
6. **Honest UI.** Loading (a skeleton shaped like the content), empty (contextual) and error (with retry) on every async surface. Never a state the system is not in: no false data while loading, "—" for an unmeasured metric, no sample data on real screens, nothing looks sent until it is. → [states and copy](references/states-and-copy.md)
7. **Copy: short, plain, white-labeled.** No vendor or internal system names, no em dashes, no AI filler or jargon, verbs on buttons, no explainer paragraphs (one functional subtitle line; one "?" tooltip for a formula). → [states and copy](references/states-and-copy.md)
8. **Tokens only.** No raw hex or palette colours in features; the accent is for wayfinding, not chrome; dark mode first-class; contrast ≥ 4.5:1; one icon set, one type scale. → [visual system](references/visual-system.md)
9. **Interaction quality.** Anything you open is a real link. Reorder by drag with keyboard support. Preview with the real consuming component. Minor actions go in the kebab. Prompt, don't gate. Destructive actions arm, then confirm. → [interaction](references/interaction.md)
10. **AI at the centre, not tacked on.** One persistent assistant that follows the person, shows its state, never moves the layout or covers a control, drafts for the person to edit, and acts only with approval. → [ai-companion](references/ai-companion.md)
11. **Root-cause fixes, not patchwork** (the prime directive).
12. **Done means proven, and looked at.** States, dark mode, every open and close exercised (close button, outside click, Escape, navigate while open, rapid reopen), keyboard, reduced motion, screenshots at 1440 light, 1440 dark and 390 read as a designer, running on localhost in the real app. → [verification](references/verification.md)

## Workflow

1. **Before:** find the owner component (shared folder, gallery, ownership map). Read the design reference. Settle the domain model before building UI on it. Read the project's own UI skill if it has one; it wins on project specifics.
2. **Build:** port a design with fidelity (layout, colour, density 1:1; tokens where values match), but mechanics are always the house components. UI first on mock data, then the backend; delete mocks before the PR. → [review and workflow](references/review-and-workflow.md)
3. **Gate:** run the source gate (below), the real build and type check, and the whole touched feature's tests.
4. **Prove:** drive the real app as each persona; measure motion, full height, alignment, layout shift and overflow; take the screenshots and read them as a designer.
5. **Report:** evidence per ask (a spec, a screenshot path or a measured number). Failures verbatim, skipped steps named, and an issues list (BROKEN / RISK / NOT DONE / UNKNOWN). Re-read the brief line by line before saying done.

Size the proof to the change: **S** (a fix) is unit tests, the covering spec and one screenshot, in about 15-20 minutes; **M** adds neighbouring specs and 1440 + 390 shots; **L** is everything (all viewports and themes, frame timings).

## The source gate

Prose rules do not hold; gates do. `scripts/ui_check.py` is a dependency-free Python gate for TS/TSX/JS/JSX/CSS:

```bash
python3 <skill-dir>/scripts/ui_check.py src \
  --primitives 'src/components/ui/*' --allow-hex 'src/styles/*' --vendor 'VendorName'
python3 <skill-dir>/scripts/ui_check.py --list-rules
```

Errors: native-control, transition-all, em-dash (in copy), role-literal, conditional-overlay, vendor-name. Warnings: literal-duration, hex-colour, role-compare, details-element, tw4-bare-var, z-literal, viewport-padding, max-h-literal, onclick-navigate, overlay-dom-guard, inline-style-literal, duplicate-component, repeated-class. Suppress a deliberate line with a `ui-check-ignore` comment; `--strict` fails on warnings; `--json` for tooling. Exit 1 on errors. Wire it into the pre-push hook or CI, and fix errors before reporting.

## Pre-PR checklist

1. Reused the existing component, or added a variant to the shared layer (no sibling).
2. Every open, close, appear, disappear and resize animates both ways at token timing; no layout jump on first load.
3. Gated by a permission key; disabled controls say why.
4. User-tunable things come from a registry plus a persisted pref with a reset.
5. The page fills the viewport in empty and full states; no dead whitespace; commit actions visible.
6. Loading, empty and error states exist, and none of them lie.
7. Copy: no vendor names, no em dashes, no explainer paragraphs, verbs on buttons.
8. Tokens only; dark mode checked.
9. The gate, the real build and the covering tests pass.
10. Screenshots at 1440 light and dark and 390, looked at as a designer; running on localhost.

## References

| Work | Read |
|---|---|
| Any markup, a new control, a one-off element, overlays, filters | [components.md](references/components.md) |
| Opening, closing, switching, lists changing, first-load shift, proving motion | [motion.md](references/motion.md) |
| Page structure, full height, panes, sticky, headers, modals sizing, mobile | [layout.md](references/layout.md) |
| Tokens, colour discipline, typography, charts, icons, dark mode, contrast | [visual-system.md](references/visual-system.md) |
| Loading/empty/error, fake data, copy rules and sweeps | [states-and-copy.md](references/states-and-copy.md) |
| Permissions, prefs and resets, links, keyboard, drag, prompts, destructive actions | [interaction.md](references/interaction.md) |
| An assistant, orb, chat panel, AI actions | [ai-companion.md](references/ai-companion.md) |
| Where files go, naming, routing, TypeScript and lint rules | [code-structure.md](references/code-structure.md) |
| Finishing work: gates, drives, measurements, screenshots, false failures | [verification.md](references/verification.md) |
| Design-first workflow, A to J feature checklist, parallel agents, PR review | [review-and-workflow.md](references/review-and-workflow.md) |

## Keep it true

If the code and a skill disagree, verify against the code and fix the skill in the same session; stale skills are worse than none. Date new facts when you add them.
