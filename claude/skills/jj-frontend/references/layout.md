# Layout: fill the page, kill dead whitespace

## Contents
- Workspace screens: the one-page law
- Every page fills the screen: the full-height law
- Page skeleton and plumbing
- Finding what stretches the document
- Sticky and scroll against the window
- Headers, buttons, one UI open
- Panes, rails and resizing
- Alignment is measured
- Modals
- Mobile parity

## Workspace screens: the one-page law

A screen someone works in (an editor, a studio tab, a two-pane form, a report tab) holds the whole job in one viewport: root `h-[var(--page-content-h)] flex flex-col`, fixed chrome (header, tabs, toolbar) `shrink-0`, every unbounded region scrolling inside its own pane (`min-h-0 flex-1 overflow-y-auto`). Each of these is a blocker on its own:

- **Commit actions below unbounded content.** Save, Publish and Add live in a pinned toolbar or header row. If reaching them can require scrolling, the layout is wrong.
- **Dead space under a control.** In a split layout every pane fills its cell (`flex-1`), textareas included (`resize-none`: the divider owns sizing). A `min-h` plus leftover whitespace is a prototype, not a product.
- **An arbitrary `max-h-[300px]` scroll box.** That number is wrong for someone's screen. Fill the space, or split it with a resizable pane whose min size keeps its pinned parts (header, footer, inputs) whole.
- **A page that grows with data.** Tables and lists on a workspace tab scroll inside their card under a pinned card header.
- **A half-empty two-pane layout.** A right half that is blank until input arrives is a designed empty state (icon + one-line claim + what will appear), not whitespace.

## Every page fills the screen: the full-height law

A page ends at the bottom of the screen on every tab and in every state, the empty one included. A card that stops a third of the way down with blank page under it is a defect, and so is one tab ending higher than its sibling.

- **Locked pages** (root fixed to the content height): the body is `min-h-0 flex-1 flex flex-col`, and whatever sits in it carries `flex-1`. Where the body splits into columns: `flex-1 xl:min-h-0 xl:grid-rows-[minmax(0,1fr)]` (the row cap stops a long column growing the page; put it at the breakpoint the columns appear), each cell `min-w-0 xl:min-h-0`. Below the breakpoint the stack scrolls inside the body, never the document.
- **A panel in a cell is a `FillCard`:** fills the cell, header pinned, body scrolls inside the card. A column of several cards is `flex flex-col gap-4 xl:min-h-0 xl:overflow-y-auto` with `flex-1` on its last card.
- **A pane with nothing in it is a `FillState`:** empty, loading and failed states fill the pane with the message centred. Never a padded card floating at the top.
- **Document pages** (long, scroll the window) need nothing while content is long; for their short states the root is `flex min-h-[var(--page-content-h)] flex-col` and the state card takes `flex-1` (`min-h`, not `h`, so the page still grows).
- **Check it by measuring:** at 1600×1000 the lowest card's bottom equals the body's bottom on every tab, and `document.documentElement.scrollHeight === innerHeight` on a locked page.
- Full-bleed panes with hairlines beat card-centric layouts and max-width containers for app screens. Use the full 16:9 width on desktop.

## Page skeleton and plumbing

```tsx
<div className="flex h-[var(--page-content-h)] flex-col gap-4">
  <PageHeader title="Loans" subtitle="Every loan by stage." right={<Actions />} />
  <div className="flex min-h-0 flex-1 flex-col overflow-hidden rounded-2xl border border-border bg-card">
    {/* fixed inner header (shrink-0) */}
    {/* body: min-h-0 flex-1 overflow-y-auto */}
  </div>
</div>
```

- Never hardcode a viewport offset. One layout token (`--page-content-h` = viewport minus chrome) is the single source of truth.
- Scroll discipline: outer `overflow-hidden`, inner `flex-1 overflow-y-auto`.
- **The `min-h-0` chain must be unbroken** from the fixed-height root down to each scroll region; one missing link and a pane silently grows the page. But `min-h-0` on stacked mobile grid items lets a bounded grid compress them instead of scrolling: make it `lg:min-h-0` and let the phone stack scroll naturally.
- Rhythm and radii come from a scale (page `gap-4`, inline actions `gap-2`; dots `rounded-full`, controls `rounded-xl`, cards `rounded-2xl` or the project's tokens).

## Finding what stretches the document

**Every scroll pane is `relative`.** An absolutely placed descendant whose containing block is outside the pane is not clipped by it: a column of `sr-only` labels can stretch the document to tens of thousands of pixels and give a locked page a window scrollbar.

To find the element that stretches the document, bisect by **clipping**, not `display: none` (hiding a flex child reflows its siblings and lies): walk down from `document.body.firstElementChild`, set `style.overflow = 'hidden'` on each child and read `document.documentElement.scrollHeight`. The child that drops it owns the overflow. When no child does but the node itself does, the culprit is an absolutely positioned descendant (usually a 1 px `sr-only`): list descendants with computed `position: absolute`, sorted by rect top. Reproducing may need real data volume.

## Sticky and scroll against the window

When a fixed top bar sits over a scrolling document, everything pinned or scrolled against the window must clear chrome whose height is dynamic (banners come and go, bars differ per breakpoint and per shell).

- One token for where page content starts (`--sticky-page-top`), one for the first viewport-Y clear of chrome (`--app-chrome-h`). Sticky against the window: `sticky top-[var(--sticky-page-top)]`. Never `top-0`, never a hand-written `calc(...)`.
- `<html>` carries `scroll-padding-top: var(--sticky-page-top)` globally, so `scrollIntoView`, anchors and focus scrolls need no per-site offset. Add `scroll-mt-*` only to clear a local sticky inside your own page.
- Sticky inside an inner scroll container (a table head in an `overflow-y-auto` card): plain `top-0` is correct.
- **A sticky footer inside a padded modal floats above the foot** (sticky stops at the scroller's padding edge): offset by the padding and pull flush (`sticky -bottom-6 -mx-6 -mb-6 px-6 border-t bg-background` for `p-6`).
- Shells declare their own chrome height once (a `data-shell` attribute or a CSS variable); banners publish their heights as variables. Never compensate at call sites.

## Headers, buttons, one UI open

- **One standard header bar.** Tab name on the left, the fixed standard buttons on the right in the same spot on every tab, tab-specific tools in between. The shell owns the bar; a screen fills slots. "The same buttons look different and are in different places in different tabs" is the failure it prevents.
- A view toggle with counts shares the filter row; a scope strip on its own row above a filter bar is a wasted row.
- **Buttons are stable.** They do not appear, disappear or shift as data loads. A modal keeps a constant size so its buttons do not fly around.
- **Only one UI open at a time.** Opening a menu closes the previous one. Mind z-order through one layer scale; no scattered z literals.
- Persistent floating things (an assistant orb, a help button) never cover a primary CTA. Pages leave the default dock corner clear, or the floating thing moves aside (see ai-companion.md).

## Panes, rails and resizing

- Multi-pane layouts are resizable and remember their sizes per user. Drag handles support the keyboard (arrows, Home), double-click resets, and sizes persist through the prefs store.
- react-resizable-panels v4 traps: numeric sizes are pixels, percentages are strings (`'17%'`); **never add or remove a `Panel` in a mounted group** (the new one arrives at ~0 width and the imperative handle goes stale): keep every panel mounted and collapse with `collapsible` + `collapsedSize={0}`; drag hit-testing is a proximity region, so the `pointerdown` target is usually a panel (read `data-separator="active"`); a neighbour's `maxSize` silently caps a separator's travel; wrap the raw group so margins are respected.
- Every collapsible rail is one component whose labels shrink with it (see motion.md).
- Draggable things use shared owners with viewport clamping, keyboard movement, persistence and reduced motion. Text is never draggable.

## Alignment is measured

- Columns line up header to body. Build header and rows on one shared column template (a grid list with subgrid), never a header `grid-cols-[...]` beside the same template on each row. Assert every header edge equals every body edge within 0.5 px, with a classic scrollbar too.
- Column alignment is a column field (`align: 'right'` for numbers) that moves the header, body cells and skeleton together; never `text-right` in a cell class.
- A summary row is the table's `totals` drawn through the same columns, never a hand-built footer.
- Table cell type: rows `text-sm` at the primitive; primary cell `text-sm font-medium`, supporting cells `text-xs`, currency and IDs mono `tabular-nums`, counts sans `tabular-nums`.
- Collapsed rail icons share one centre line. Logo, page title and tabs share one left edge with the header; right edges line up too.

## Modals

- Default modal widths are unprefixed so caller overrides work. To size one, pass a plain `className="max-w-md"`. **Never `sm:max-w-*`**: a media-query utility beats plain utilities in the emitted cascade and the override silently loses.
- Modals resize smoothly (a smooth-height body) and what changes inside them folds through the collapse primitive, never a bare conditional.
- A modal settles over a couple of frames: let it settle (~500 ms) before a screenshot.

## Mobile parity

- Bottom sheets on phones for popovers, menus and modals.
- No hover-only actions on touch. Touch targets ≥ 44 px (an invisible `after:-inset-3` widens a small icon's hit area without changing its look).
- Nothing jumps when the mobile browser bar shows or hides (use `dvh`/`svh` deliberately).
- Phone keyboards: pad and re-pin a chat transcript for the iOS keyboard; set `interactive-widget=resizes-content` in the viewport meta for Android.
- Tab bars become swipe rails on phones; never leave tabs unreachable off-screen.
- No horizontal page scroll at 390 px. Check for clipped overflow too: `overflow-x: clip` on html/body hides a too-wide row from the document probe, so compare an element's right edge with its clipping ancestor's.
