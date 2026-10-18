# AI at the centre, not tacked on

Centre the product on the assistant instead of bolting a chat box onto a finished app. The assistant is one persistent companion that follows the person across pages, shows what it is doing, can answer and act, and never takes control away from them.

## Contents
- One companion, mounted once
- State and signals
- Placement: stages, one spot, docking
- Never move the layout; never cover a control
- The panel
- Quiet over reading content
- Chat surface
- Actions and approval
- Performance budget
- What to verify

## One companion, mounted once

- One companion element (an orb, a particle cloud, an avatar) lives in the app shell and is **never remounted**. Navigation morphs it; a remount loses state and flashes.
- A screen never computes the companion's coordinates. It renders a named **stage** element where the companion should sit (the empty home area, behind a chat thread, above a sign-in headline). The stage measures its rect (on mount, ResizeObserver on itself and `main`, window resize, and a short rAF settle window to follow scene transitions) and publishes it; the newest stage with a non-zero rect is active.
- Mark every AI-touched item with one mark component, and give every record, pane or row group an "Ask" affordance that focuses the assistant on that record with a page-specific suggestion.

## State and signals

- A small state machine: `idle | reading | responding | acting | done | failed`. Each state has a visible form (a page glyph at rest, a thinking shape while reading or responding, an acting shape, a check, a failed ring with a shake). If a pose cannot morph, pulse instead (slow while thinking, fast while acting or failed).
- Features signal through one tiny event bus (`signal('acting', element)`, `signal('done')`, `ripple(at)`), so the real assistant and any mock share one path. A busy signal holds until idle/done/failed or a timeout; done holds ~1.1 s, failed ~2.2 s. Merge a transient signal with the stored status: a non-idle signal wins, the higher-ranked one when both are busy.
- Live AI activity is visible where it happens (an agent replying, a draft waiting, a handoff paused) with one shared treatment.

## Placement: stages, one spot, docking

- **One position for the whole app**, never per page: a persisted spot (`{x, y} | null`) and a dock (`free | header | nav`), parsed at the pref boundary with a schema. Route changes never move it; assert the centre is within 1 px across routes and a reload.
- Default to a dock zone the shell owns (a slot at the end of the header's standard cluster, or a row in the nav), not a corner of `main`: every corner of `main` holds some screen's last row. Floating is a choice.
- Dock zones open (animate width or rows from 0) while a drag is live and when docked; closed they are 0 wide and `visibility: hidden`, leaving no hairline. Drop regions paint over the bars during a drag with a caption ("Drop to pin").
- Gestures: a drag threshold (~7 px; a shorter press toggles the panel), Escape cancels a drag and the companion returns, arrow keys nudge (16 px, Shift 4 px), Enter on the focused orb opens the panel, a drag never opens it. Clamp every placement into `main` using the companion's own hit size.
- Settings exposes the dock choice and a "reset position"; "Reset all preferences" clears it.

## Never move the layout; never cover a control

- **Nothing in the app moves to make room for the companion.** No reserved header padding, no clearance attributes. It overlays.
- It must never cover a primary CTA or an interactive element. Mark controls it must avoid (`data-dock-avoid`), and let the companion lift just enough to clear them (with a gap and hysteresis so it does not jitter), or fade and shrink out of the way when it cannot, returning when the overlap ends. On phones, keep it clear of the hero CTA and sticky CTA bars.
- A canvas companion is `fixed inset-0` with a `clip-path` so it never paints over the nav; during a drag or flight the clip opens fully, then grows back once the particles report settled. No timer guesses the landing.

## The panel

- The panel is a floating window (resizable, draggable by its header) and opens *at* the companion: with a stored offset it reopens where it was relative to the orb; without one, toward free space. Docked, it opens at the page's declared corner, and pages can name controls it must clear (it rises above the highest) and a ceiling (it shortens rather than rising past it).
- **The panel closes only by an act on the companion:** its close button, Escape while focus is inside it, the orb tap, a shortcut, "Full view", a drop on a dock zone. An outside click, a nav click or a route change keep it open.
- It registers a window overlay layer: page shortcuts work while focus is outside it, and Escape reaches it only from inside. Closing hands focus back to its opener.
- Open state and the conversation persist across reloads (a session id and conversation id), and a link can deep-open a conversation.

## Quiet over reading content

When the companion rests over text or controls, it fades ("quiet") instead of the layout moving. Decide it by measurement, never by tagging elements by hand: sample a small grid inside the companion's box with `document.elementsFromPoint`, skip the companion's own elements, and count the topmost element as reading content when it is a control, media, or owns a non-blank text node. Re-measure on spot change, route change, resize, scroll inside `main` and DOM mutations, throttled (~120 ms). Ease the value; reduced motion applies it instantly.

## Chat surface

- A centred thread column (~680 px) that auto-scrolls on new content and stops following once the person scrolls up.
- A turn's tool calls stream as plain-word rows ("Reading your matches", then a check with its sentence when settled) that fold into "Worked through N steps" once the answer text starts. It should feel alive, like a modern chat app: steps stream, a cursor shows streaming, and **Stop is always there**.
- Messages: user bubbles, assistant rows with the AI mark, source chips, action pills, suggestion chips.
- Composer variants for the home (a card) and the panel (inline). One shortcut (⌘K) focuses the composer on home and toggles the panel elsewhere.
- Every text block is `min-w-0 break-words`.

## Actions and approval

- **AI drafts go into the box for the person to edit**; the person stays in control.
- An action that changes something (sends, accepts, connects, requests) goes through a confirmation card showing exactly what will happen and what will be shared or kept hidden, and the result says whether it was approved. Never claim an action happened unless the approval and the result say so.
- Approved actions recheck permissions at execution time.
- Graceful degradation: when the AI service is slow or offline, a deterministic local planner answers the common intents so the product still works.

## Performance budget

DPR ≤ 2, one `requestAnimationFrame` loop, paused when hidden or offscreen, disposed on unmount. A still mode renders on state changes with no loop for: reduced motion, a software renderer (request the context with `failIfMajorPerformanceCaveat` first), and a blown frame budget (several consecutive frame intervals over budget). The companion still works in still mode; it just does not move. Expose the mode on the host (`data-motion="animated|still|off"`) for specs.

## What to verify

- The canvas survives navigation; one spot across routes and a reload within 1 px.
- No companion/control overlap on every route at two widths and at phone width, with panes scrolled to their ends.
- The panel stays open through outside clicks, nav clicks and a reload; Escape outside it runs the page's own Escape; closing returns focus to the opener.
- Quiet reaches ≥ 0.9 within 1 s over text and ≤ 0.05 over empty space; reduced motion has no intermediate frame.
- Drag, dock, undock and the drop regions animate both ways (sampled per frame).
