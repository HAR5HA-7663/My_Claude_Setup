# Components: every element is a component

## Contents
- The rule
- Ownership by layer
- Banned native controls and their replacements
- The primitive roster every app should own
- Overlays and floating layers
- Filters: one framework
- Component rules

## The rule

- A one-off gets a named component the first time it exists, so the next similar need reuses it.
- **Before writing markup, find the owner.** Look in the shared component directory and the component gallery (a dev route that renders every shared component with its variants, each under a stable `data-testid`). If your project has neither, list the shared folder before you write anything.
- If something nearly fits, **extend it with a variant** (widen a prop type, add a size or tone). Never copy it into a feature folder and tweak it.
- **A duplicate of a shared control is a review-blocking defect, not a nit.** It also means the original keeps asserting old behaviour.
- When two similar things exist, consolidate them into one component.
- Less hardcoding, more configurability: props are data and callbacks.

## Ownership by layer

| Layer | Holds | Rule |
|---|---|---|
| Primitives (`packages/ui` or `src/components/ui`) | Generic controls, overlays, motion, layout primitives, variants | Domain-agnostic. The only place raw `<button>`, `<input>`, `<select>`, `<textarea>` may appear. |
| Domain-aware shared (`src/components`) | Pieces that read the store or config and that 2+ features need | One file per component, plus a gallery item. |
| Feature compositions (`features/<domain>/components`) | Named compositions (`ThreadRow`, `LeadCard`) | One file per component. A basename that exists in another feature means move it up a layer. |
| Screens | Composition only | Under ~200 lines. A 400-line page hides two hooks and three components. |

Record the owner of every new interaction family (a new kind of overlay, a new list behaviour) in the project's UI ownership map, so the next need finds its owner before a sibling gets built.

## Banned native controls and their replacements

Native controls draw OS chrome, ignore the tokens and snap open and shut.

| Banned | Replacement |
|---|---|
| `<select>` | The house select: an `options` array with groups and separators, sizes, auto-selects a lone option, optional `searchable` (a combobox with search at the top) for long lists, an optional per-option `description` shown only in the open list |
| Multi-pick `<select multiple>` | A multi-select dropdown / multi-combobox that stays open while picking |
| `<datalist>` | A suggest input: free text plus floating suggestions |
| `<input type="date">`, `type="time"` | Date and time pickers. Values are `"YYYY-MM-DD"` strings, never `Date` objects (UTC-midnight shift). Best form: a real text input that masks digits into MM/DD/YYYY as you type, accepts pasted ISO or month-name forms, commits on Enter/blur, reverts junk, and still opens a calendar; on phones a tap-to-open sheet |
| `<input type="color">` | A hue slider (a styled native range input is fine: it renders inline and takes tokens) |
| `window.confirm` / `alert` / `prompt` | The house confirm dialog (`title`, `description` as a node with the thing at stake in bold, a danger variant, a nesting level). Fire-and-forget: it closes on confirm and the surface toasts the outcome |
| `<details>` inside a modal, drawer or wizard | An animated `Disclosure` (summary button + turning chevron over the collapse primitive) |
| Hand-rolled search box | A search field with a clear button where Escape clears |
| Hand-rolled "?" help button | One `InfoTip`: a real, keyboard-reachable button with the house tooltip and a screen-reader label; wired into section, field and column primitives as a `hint` prop |
| Hand-written Enter/Escape handlers on fields | One `commitKeys({ onCommit, onCancel, multiline })` helper: Enter commits (⌘/Ctrl+Enter when multiline), Escape cancels, and a handled Escape stops propagating so nothing behind the field also acts |

## The primitive roster every app should own

Reach for these before writing utility classes. The names are suggestions; what matters is that each concept has exactly one owner.

- **Marks and text:** an AI mark (the one sign the assistant touched something: dot, chip, avatar variants), a tone tag/badge, count pill, status dot and status label (dot + coloured text), a kicker (mono eyebrow), a mono text component for numbers and footnotes (tabular nums), the brand logo (an SVG with `aria-hidden`; the link around it carries the name), spinner, skeleton.
- **Controls:** button (variants and sizes, including icon sizes), icon action (icon button with a tooltip label and `pressed`), chip / chip group / segmented control, status pills (a row of count pills with tone and selection), search field, input variants (including a ghost title-sized inline-rename field), textarea variants (prose, composer), switch, checkbox, toggle group, field / label / description, setting rows, alert (default, destructive, warning, success, hint, note; `role="note"` for hints).
- **People:** initials avatar, a person cell (avatar + name + sub + mark + trailing).
- **Layout:** screen header slots (title, kicker, subtitle, leading, meta, tools, customize), toolbar, stat strip, pane group / pane (scroll panes that are focusable and named only while they overflow and hold no control, so keyboard users can scroll them), rail with collapse and reveal, resizable rail and resize handle (controlled size, min, max, keyboard arrows, Home, double-click reset, persisted), row list / row (list and card density, `handle` and `control` slots), card (default, bordered), pane footer, bulk action bar (collapses to nothing at zero), empty state, a not-connected notice (an icon disc, one-line title, one-line description, optional action; never a sample row instead).
- **Data:** a grid list (one column template on the list root shared by header and rows via subgrid; a leading track for avatar/select, an actions track sized from the widest row measured in a layout effect, sticky first column, sideways scroll), table family, tabs (manual activation by default so a focus moved by code never switches the tab), collapsible, accordion, progress, checklist (title, "N of M done", progress, rows with done tick or reason the person cannot act, collapsible).
- **Overlays:** dialog, alert dialog, sheet, drawer, popover, dropdown menu, context menu, tooltip, hover card, command dialog, floating window. Always mounted, driven by `open`.
- **Motion:** presence (surface, panel, collapse, slide, expand, mark), animated list, animated text, scene transition, reorder / sortable list with a drag overlay, toast.

A link or button that belongs on a clickable row goes in the row's `handle` or `control` slot, never in its children: those render inside the row's own button and nest interactive elements.

## Overlays and floating layers

- **One floating-panel primitive** (portal, click-outside, Escape stack, flip and reposition, a bottom sheet below 640 px). Menus, kebabs, pickers and popovers ride it. Never hand-roll either half.
- Every popover panel splits on whether it is a phone sheet: full width in the sheet, a fixed width otherwise, `dvh` list caps in sheets.
- Menus clamp to the available height and scroll; a menu never runs off the viewport. Long lists fold into a submenu item (a chevron row whose flyout opens on hover with safe-triangle intent, or on click, with arrow-key walking; inline on phones).
- **An overlay layer registry** decides who owns Escape and when focus returns. Each dismissible owner registers a layer while open (kinds: surface, hint for tooltips, window for persistent floating windows, exit while closing). Keyboard guards ask the registry (`overlayOwnsEscape(event)`, `overlayLayers.count()`); **never query the DOM** for `[role=dialog][data-state=open]`. The registry claims Escape in the capture phase.
- On close, focus goes back to the trigger (the element whose `aria-controls` names the content), else to what was focused when the content mounted. A focus hand-back never opens a tooltip.
- **Z ladder:** one layer scale (rail, bar, overlay, nested, popover, window, toast, report). A child overlay opened from inside another uses the nested level; never open a lower-level dialog from inside a higher-level modal (it paints behind its host and every click lands on the host).
- Portaled pickers mark their layer (`data-floating-layer`) so a picker inside a popover does not close its host, and take their z from a floating-tier context, never a literal.
- React `autoFocus` does not survive a portal: focus in an effect plus `requestAnimationFrame`.
- A blur-commit editor hosted in a popover needs a capture-phase `mousedown` flush: the panel unmounts on mousedown before blur fires.
- A persistent floating window registers a window layer: page shortcuts keep working while focus is outside it, and Escape reaches it only while focus is inside.

## Filters: one framework

Every list uses one filter framework; a feature-local filter model, codec, chip, editor or views menu is a review-blocking duplicate.

- A screen declares `FilterField<T>[]` (types: multiselect, select, daterange, boolean, text, numberrange; each with key, label, group, operators, options, pinned + defaults, date presets, a unit, and one client accessor).
- URL state through one hook (`useUrlFilters(fields)`), with one URL grammar (for example `key=not:a,b`, `key=empty:`, `key=30d`, `key=1~5`).
- Rows filter through one function (`applyFilters(items, fields, state)`).
- One filter bar with a saved-views slot. Toolbar order: search, views, chips, add filter.
- Saved views save **filters only**, never display mode, sort or group-by. They support a pinned landing view, per-user hidden presets with a "restore default presets", reordering, and sharing. The pinned view auto-applies under three guards that are the feature: wait for prefs to be ready, skip when the URL already carries filters (deep links win), and decide once per mount.
- When some filters run only on loaded rows, say so once with a shared hint component.

## Component rules

- Name a component on first use.
- Props are data and callbacks. **Call sites set layout and data, never colours, radii or timing.**
- Repeated records key by stable ids, never the array index.
- Loading, empty, failed, disabled and done states use the same component family as the normal state.
- Icons: one set (lucide), one size scale (16/17 px default, 14 tight, 20/24 emphasis), one stroke width. No emoji as icons, no ad-hoc inline `<svg>` in features.
- Inline `style` carries CSS-variable keys only (`{"--bar": value}`); geometry goes through a class that reads the variable.
- Compose classes through `cn()` (clsx + tailwind-merge), never template strings. Trap: a `leading-*` class before a `text-[size]` in `cn()` is dropped by tailwind-merge; put leading after the size.
- Mono text, footers, search, the AI mark and pills come from their components, never rebuilt from utility classes.
- A class list of 48+ characters repeated in 3+ files is a missing component.
