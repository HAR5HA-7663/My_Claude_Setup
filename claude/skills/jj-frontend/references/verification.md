# Verification: done means proven, and looked at

## Contents
- What "done" requires
- Gates
- Drive the real app
- Measure what can be measured
- Screenshots, read as a designer
- Size the proof to the change
- Gotchas that fake failures (or fake passes)
- Drives must not touch real data
- Reporting

## What "done" requires

A UI change is not done until:

- Loading, empty and error states exist and none of them lie.
- Dark mode works.
- **Every open and close you touched has been exercised:** close button, outside click, Escape, navigating while open, rapid reopen. The exit runs before removal.
- Keyboard works: tab order, focus ring, Enter/Space, arrows on drag handles and menus. Reduced motion still shows and dismisses.
- Screenshots at **1440 light, 1440 dark and 390** (plus 1280×800 and 1920×1080 for dense screens) have been looked at as a designer.
- It runs on localhost in the real app on its usual port, so the person can look. Never build a side page or harness for them to look at instead.

## Gates

Prose rules do not hold; gates do. Run, in order:

1. The source gate: `python3 <skill>/scripts/ui_check.py src` (configure `--primitives`, `--allow-hex`, `--vendor` for the project; wire it into the pre-push hook or CI). Fix errors; triage warnings.
2. The real build and type check (the project's `build`, not only `tsc --noEmit`), lint.
3. The covering tests, the whole feature's suite, not only the new tests (stale tests live in files the change never touched). Report failures verbatim and name skipped steps.

Never weaken an assertion or add a broad exclusion to pass a check. Passing checks prove the covered behaviour, not frame pacing on every device.

## Drive the real app

- Log in through the real UI as the seeded personas, one per role (an LO, a brokerage owner, an admin, whatever the product's roles are). For multi-role features, drive each role and collect ranked, concrete findings.
- Click through the happy path, empty, loading and error, dark mode, phone width, and every open/close.
- **Point the drive at the right app first.** Confirm the base URL your test runner actually reads, and that the server on that port is your checkout (fetch a version endpoint or assert a string only your branch renders). A whole drive can run green against another checkout.

## Measure what can be measured

- **Motion:** frame sampling (see motion.md). Intermediate values at one third of the token, settled or removed by token + 60 ms.
- **Full height:** the lowest card's bottom equals the body's bottom; a locked page has `scrollHeight === innerHeight`.
- **Column alignment:** every header edge equals every body edge within 0.5 px.
- **Layout shift:** a CLS budget on cold and warm loads of every main route at 1440 and 390.
- **Overflow:** no horizontal overflow at 390, comparing elements against their clipping ancestors (document-level probes miss `overflow-x: clip`).
- **Contrast:** axe (or equivalent) in both themes, ≥ 4.5:1.
- **Overlap:** a floating companion or dock covers no control on any route.

## Screenshots, read as a designer

Assertions prove elements exist; only looking catches dead whitespace, a clipped footer, a control that demands scrolling, an empty pane with nothing designed in it, misaligned edges, truncation and contrast. A surface can pass every functional check and still be awful UX. After each screenshot, read it and name what is wrong before moving on.

- SVG-heavy work needs a WebKit screenshot as well as Chromium.
- An element screenshot of a tall surface inside an `overflow-y-auto` container stitches blank below the fold: scroll the container and take viewport shots.
- Let modals and theme toggles settle (~500 ms) before a shot; mid-animation frames show ghosting.
- Porting a design canvas: render each artboard of the design export to a screenshot, read exact px and colours from its inline styles, then drive the ported page against those shots. The canvas is the decision; use house tokens only where the value is identical.

## Size the proof to the change

| Size | Proof |
|---|---|
| S (a small fix) | Unit tests + the one covering spec + one screenshot. Inline, ~15-20 minutes including deploy. |
| M (a feature slice) | S + up to three neighbouring specs + 1440 and 390 shots + a ledger row per ask. |
| L (a new surface) | Everything: repeats, all viewports and themes, frame timings, a decision entry. |

Run the full browser gate nightly instead of on every small change. Small asks should take small time.

## Gotchas that fake failures (or fake passes)

- **Dev StrictMode re-runs every effect.** A one-shot effect that loses a race in a single flush gets a free second run on localhost and passes; production stays broken. Reproduce mount and navigation timing bugs on the deployed app (read-only) or in a unit harness.
- **Theme toggles wear `aria-pressed`.** `button[aria-pressed]` with `nth()` can pick the theme toggle instead of your control. Locate by accessible name.
- **A locator keyed to text your interaction changes self-invalidates** and silently re-resolves onto the next match. Locate state-dependent controls by role, position or a stable `aria-label`.
- **Collapsed content stays mounted.** A clipped child keeps its bounding box, so `toBeVisible()` passes and `toHaveCount(0)` counts it. Assert what the surface says, or check `closest('[inert]')` / `aria-hidden`.
- **Responsive primitives render twice** (desktop cells plus a CSS-hidden mobile card): dedupe text reads and filter `{ visible: true }`.
- **Rows that open records are links**, often with the visible text in sibling cells, not inside the anchor. Locate by href or the anchor's accessible name. To open in a new tab: wait for the popup page around a `ControlOrMeta` click, then wait for its URL to leave `about:blank`.
- **URL-backed state re-renders async:** read results with `expect.poll`, never an immediate DOM read.
- **Dark mode from a stored theme ignores `emulateMedia`.** Set the stored theme before load and assert the `dark` class on `<html>`.
- **Exits linger** (~150-350 ms): a test asserting a closed panel is gone must wait for removal; scope text assertions to `main` so a closing panel does not match.
- **`:scope > div` does not reliably resolve to a direct child** in some locator engines; use an XPath `./div[1]`.
- **An `aria-disabled` (not `disabled`) submit** that surfaces missing-field notes needs `click({ force: true })`.
- **A wedged browser context** (clicks reach the element but no handler fires; `el.click()` from evaluate works): close the browser and start a fresh page. A first dev-server boot that re-optimises deps reloads the page mid-login; wait for network idle before filling.
- **A dev server started in an ignored scratch worktree may not hot-reload:** restart it after edits or you measure old code.
- **Exports:** a generated `.xlsx` can pass every Mac and unit check and still open corrupt in Windows Excel; validate with the official OpenXML validator after touching the writer.

## Drives must not touch real data

- Never press a real submit in a send/push/broadcast flow against a stack that can reach real vendors or real contacts. Refuse the write at the network layer (`page.route` the endpoints) and answer it yourself.
- Fixtures seed and delete only QA-unique names; never delete by a label the app itself mints.
- Parallel agents need disjoint ownership: their own files, dev port, test database and screenshot folder (test runners wipe their output dir per run). One integrator runs the one full build.
- Production data changes are always the owner's call.

## Reporting

- Claims need evidence: a spec, a screenshot path or a measured number per ask. "Done" without evidence gets rejected.
- Re-read the brief line by line after a delivery; every sentence is a requirement. Keep an ask-by-ask ledger for big briefs (each ask a row, DONE only with evidence).
- Report outcomes faithfully: failing output verbatim, skipped steps named, and an issues list (BROKEN / RISK / NOT DONE / UNKNOWN).
- A fix you just wrote moves a bug report to *testing*, not *done*. The reporter or owner closes it.
