# Motion: everything moves, both ways

## Contents
- The contract
- Tokens
- Which technique for which case
- Rules
- First load and layout shift
- Library traps
- Proving motion (measurement method)

## The contract

**enter → usable → exit → removed.** Both directions animate, on every side and variant. The close plays fully before the node leaves the DOM. Reopening during an exit works. "Everything" is literal: modals, drawers, sheets, popovers, dropdowns, menus and submenus, tooltips, hover cards, tabs, rail and panel collapses, rows entering and leaving, numbers changing, status text, route changes, data arriving, a box resizing because its content changed.

Before calling UI done, ask of every conditional render: does it animate in AND out? A bare `{cond && <Thing/>}` for anything visible is a defect.

## Tokens

One motion config owns timing, mirrored once in CSS variables. Never a literal duration in a feature.

| Token | ms | Use |
|---|---|---|
| control | 160 | hover, press, toggles, tooltips, marks, small status changes, toast exit |
| surface | 220 | popovers, menus, dialogs, tab content, cards appearing |
| panel | 280 | sheets, drawers, floating windows, scene (route) transitions |
| collapse | 240 | height folds, accordions, list rows in and out |
| feedback | ~1100 | how long a done/failed signal holds |

- Travel distance: 8 px rise or slide for surfaces.
- Entry easing: `cubic-bezier(0.2, 0, 0, 1)` (or the iOS sheet spring `cubic-bezier(0.32, 0.72, 0, 1)` for sheets). Exit easing: a symmetric `cubic-bezier(0.4, 0, 0.6, 1)` so a 160 ms close is visible for all 160 ms. An expo-out curve finishes most of a close in its first third and reads as instant.
- Smooth in and smooth out, never linear: "smooth stop and start".
- Tailwind: `duration-(--motion-surface) ease-(--motion-ease)`. Never `transition-all`; never a bare `transition-colors` (its default 150 ms is not a token). Name the properties: `transition-[opacity,transform]`.
- Keep the values in one TS config and one CSS file, and make the gate fail if they drift apart.

## Which technique for which case

| Case | Technique | Timing |
|---|---|---|
| Dialog, alert dialog, command palette | Content keeps a pop keyframe, overlay a fade; exit keyframe on `data-state=closed` | surface |
| Popover, dropdown, select, combobox, submenu | Pop keyframe, travel from `data-side` | surface |
| Tooltip, hover card | Pop at control timing; explicit open/close delays per use | control |
| Sheet or drawer (any side) | Slide keyframe from the side | panel |
| Floating window | Window-in/out keyframe (scale + fade) | panel |
| Collapsible, accordion | Height from the measured content height + opacity | collapse |
| Tabs content | Force-mount panels; outgoing panel pops out of flow and fades while the incoming one rises | surface in, control out |
| Checkbox/radio marks, switch thumb, toggle | Transition named properties at control | control |
| Toast | Override the library's own timings to the tokens | surface in, control out |
| Conditional inline content | A `Presence` primitive (kinds: surface, panel, collapse, slide with side, expand for width, mark) | per kind |
| A pane that slides in from an edge | `Presence kind="slide" side="right"` (translate 100% + opacity) | panel |
| A side pane that pushes its neighbour | `Presence kind="expand"` (width 0 → auto + opacity, overflow hidden) | collapse |
| A rail that collapses to icons | Width transition + a `RailReveal` for labels (flex-grow 1 → 0 + opacity) and kickers (grid rows 1fr → 0fr) | surface |
| Screen change inside a feature (tabs, wizard steps) | `SceneTransition scene={key}` mode wait (exit, then enter) | control |
| Screen change in the app shell | Crossfade: incoming fades and rises 8 px, outgoing is `absolute inset-0` and `inert` | panel in, control out |
| Rows that come and go | `AnimatedList`: rows present at mount and the first fill of an empty list render settled (that is the data landing); later rows animate | collapse |
| Numbers and status text that change | `AnimatedText` | control |
| A box whose content changes size (modal body) | `SmoothHeight`: pin to the measured height (ResizeObserver) and ease between values; follow children that animate their own height frame by frame | collapse |

Every animated node carries `data-motion` (reduced motion targets it) and a `data-state` (`open`/`closed`, `active`/`inactive`) so a spec can find its phase.

## Rules

- **Keep overlay owners mounted; drive them with `open`.** Never `{open && <Dialog/>}`. Radix-style primitives wait for the exit animation before unmounting.
- **Entry is CSS, not a two-rAF class flip.** The rAF entry silently drops under heavy content ("pops up instantly, closes smoothly"). Use keyframes (first paint is the from-state) or `@starting-style` (Tailwind `starting:` variants).
- **An exit keyframe needs its own `animation-name`.** `same-name ... reverse` updates the finished animation in place instead of restarting it, so the surface snaps shut.
- **A surface whose props die with its owning state** (a cleared URL param, a deselected row) stays mounted for one exit replaying its last live children (`useExitReplay` / `useLastPresent`). Never hand-roll a freeze with timers. A call site that must unmount a closed child uses a delayed unmount sized to the exit.
- **Portal submenus** so they animate and never clip.
- **A menu item that toggles a mark** keeps the menu open (`onSelect={e => e.preventDefault()}`) when the change should be seen.
- **Animate opacity and transform.** Animate height only for an intentional collapse.
- **In-flow collapses carry their spacing inside** (`pt-*` on the content, never `space-y` on the parent: a folded zero-height child still gets the gap).
- **Collapsed content is `visibility: hidden` + `inert` + `aria-hidden`.** Open content inherits visibility; never force `visible` on something that can sit inside a hidden panel.
- **Nothing absolutely positioned lives inside a collapse** (it wraps in `overflow-hidden`; an absolute panel shows as a clipped sliver). Portal it through the floating-panel primitive.
- **No timers to guess removal.** Exiting content is `inert`. Focus returns to the trigger.
- **A leaving scene never writes the URL.** An effect that syncs screen state to search params, redirects to a default tab or applies a pinned view checks that its scene is still present; otherwise it rewrites the URL of the screen that replaced it.
- **The crossfade outlet captures the outgoing route's element** (e.g. `useOutlet()`), so the leaving block keeps rendering the old route instead of a copy of the new one.
- **Collapsible rails never swap a collapsed component for an expanded one.** One component, labels shrink with the width.
- **One persistent canvas** (a particle orb, a map) is mounted once in the shell; navigation morphs it, never remounts it.
- **Reduced motion:** tokens drop to ~0.01 ms, `[data-motion]` forces it on inline durations, motion libraries get `duration: 0`. It shows and dismisses instantly and never delays interaction or unmount.
- Motion library imports come from one place (`motion/react`), and its transitions are built from the tokens (`motionTransition(kind)`, `motionExit(kind)`).

## First load and layout shift

First load counts. Data popping in and pushing the layout is a defect ("pages hiccup on first load").

- A pending surface **holds its loaded size, or takes none.** Skeleton rows shaped like the real rows when the size is known; a zero-height pending host whose line overlays the region otherwise.
- A block that appears *with* the data uses a presence with `arrival="settled"`: no entry motion on its first show; every later show and every exit animate.
- A tab whose sections each load their own data holds them all behind one pending state until every source answered, then fades them in together, so no section collapses open under another.
- **The header holds still across navigation.** One row of one height on every screen; per-screen subtitles and tools arrive and leave with the scene. Never grow or shrink a bar above the scene stage on navigation: the layout-shift API counts every frame of it.
- A lazy route's chunk never paints a fallback inside the shell. One `Suspense` above the shell's scene transition holds the current scene until the chunk resolves (router transitions keep revealed content), then crossfades. Preload route chunks on nav item hover and focus.
- Guard it with a spec: every main route at 1440 and 390, cold and warm, against a CLS budget.

## Library traps

- vaul (drawer) hardcodes a 500 ms transition; override its keyframes and release transitions to the panel token with `!important`, and know its `onAnimationEnd` still fires at 500 ms.
- sonner removes a toast ~200 ms after dismiss regardless of CSS, so the toast exit uses the control token. Its collapsed-stack rule has high specificity; beat it with a more specific rule.
- Radix renders a closed Select's content into a detached fragment: register its overlay layer from the root while open, not from inside the content.
- A Base UI / Radix Dialog marks every other body-level portal `aria-hidden`/inert at unpredictable times; opt a persistent portal out (e.g. `aria-live="off"` on its root) instead of fighting the attribute from React.
- A `fixed` element rendered inside an animating dialog must portal to `body`: the dialog's transform makes it the containing block.

## Proving motion (measurement method)

Never prove motion by reading class names. Sample frames.

1. Start an in-page `requestAnimationFrame` recorder that samples the target every frame: `data-state`, computed opacity, transform, rect, and the durations and easings of every running animation from `element.getAnimations()` (CSS animations, CSS transitions and WAAPI all appear there).
2. Perform the action (click, Escape, hover) and record until `token + 320 ms`.
3. Find the phase start: the first frame in the DOM with the open state and a running animation (enter), or with the closed state (exit).
4. At one third of the token: the value is strictly between 0.05 and 0.95 (opacity, or 1 - offset/size for slides), the node is still present with the closed state on exit, and the running animation's duration equals the token ± 40 ms.
5. At token + 60 ms: settled at 1 (enter), or removed / `display: none` (exit). State changes (switch thumb, toggle background) differ from both start and end at one third and settle after.
6. On a starved main thread (no frame within 30 ms of one third), fall back to a page-wide motion log (patch `Element.animate`, listen to `animationstart`/`transitionstart`): the property's animation must have run at the token with the token easing. A jump cut, a wrong duration or a wrong easing still fails.
7. Reduced-motion run: no frame has an intermediate opacity.
8. Turn tracing off for these specs: trace screenshots stall the main thread.

Feature specs reuse helpers rather than re-implementing the recorder: `expectAnimatedOpen(page, trigger, selector, kind)`, `expectAnimatedClose(...)`, `expectAnimatedToggle(...)`. The selector must resolve to the node that carries `data-state` and the motion class, not a child. Sheets animate transform: sample the overlay's opacity and assert the panel's `data-state` separately.

For height folds without a recorder: sample heights between before and after (intermediate values mean a transition; a snap yields none). Wait ~500 ms after any unsampled click that starts a fold, and use a tall viewport so a height-capped modal is not scrolling. Probe smoothness in the populated state, not the empty one.
