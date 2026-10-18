# Visual system: tokens only

## Contents
- Tokens
- Colour discipline
- Typography and numbers
- Status dictionaries
- Charts: one colour system
- Icons
- Dark mode and contrast
- When the user names a colour

## Tokens

- No raw hex, rgb or named palette colours (`gray-400`, `red-500`) in feature code. Add a token in the design-system layer and use it. The only exception is a status dictionary's sentiment classes.
- Tokens cover surfaces (background, surface-1/2/3, card), a text scale (primary, secondary/muted, faint), borders (border, border-strong), one primary, sentiment (success/pos, warning, error/neg), layout (page content height, chrome height, sticky top), radii, shadows, motion, and a layer (z) scale.
- **Tailwind v4: a token in a utility is `bg-(--pos)`, never `bg-[--pos]`.** The v3 bare-variable bracket form compiles to `background-color: --pos;`, invalid CSS the browser drops with no build warning; only a screenshot catches it. The paren form takes opacity modifiers (`text-(--neg)/30`); `bg-[var(--pos)]` also works. Token greps must cover `(--x)`, `[var(--x)]` and the broken `[--x]`.
- Inline styles carry CSS variables only; a class reads them.
- If the design file and the code disagree, the code is the truth: verify there, then fix the doc or skill in the same session.

## Colour discipline

A product's feel dies from drift faster than from bugs. The pattern that holds:

1. **Neutral surfaces carry everything.** Opaque cards with a hairline border and a neutral text scale. Glass and gradients are opt-in emphasis, not the default.
2. **The accent is for wayfinding, never chrome.** The active nav item, an icon stroke, a thin accent line, hero text. Not CTA fills, not body text. One accent element per screen region.
3. **Sentiment colour only where it means something.** Success, warning and error dots and text for status; nothing else is coloured.
4. Charts are the exception: they paint through the chart colour system below.

## Typography and numbers

- One type scale through utility classes (`t-display` hero, `t-h1` page title, `t-h2` section/modal title, `t-eyebrow` uppercase labels, `t-num` for figures). Body `text-sm`; meta `text-xs` in the faint tone.
- Numbers in tables, amounts and IDs are mono or `tabular-nums` so columns do not jitter.
- An unsized table cell inherits the browser's 16 px unless the primitive sets the row size; set it at the primitive.
- Two fonts at most (a sans for UI, a mono for figures and code); a display face only for big numerals or hero type.

## Status dictionaries

One const dictionary per surface, `Record<Status, { label; tone | dot }>`. Colours, labels and sort order live in one place, and adding a status is one line. Statuses are per-surface on purpose; do not centralise unrelated vocabularies.

## Charts: one colour system

Every data visual (donut, bar, column, track, meter, map, line) paints through one chart-colour module and is drawn by a chart primitive. Hand-rolling a track, a donut or a per-chart colour list is a review-blocking duplicate.

- **Share** (parts of a whole with no meaning: branches, people, vendors): the biggest part wears the brand accent, the rest a quiet ink, ranked by value.
- **Meaning** (stages, statuses, sentiment, outcomes): declare one meaning palette next to the vocabulary (progress order plus keys like success, neutral, muted, caution, warning, stop) and pass it to every chart of that vocabulary.
- **Magnitude** (bars, columns, tracks): the accent ramp anchored to the chart's full extent, so a short bar stays at the start of the ramp and only the largest reaches the end.
- **Meters:** one ring and one progress bar component (a tone for a verdict, a complete state for success). **Lines:** the brand stroke; red only for a real downtrend.
- **Number tiles:** value large, a coloured sparkline in an inset strip between the value and a bottom-pinned note; an all-zero series draws a flat muted baseline; no series means no reserved strip.
- **Hover never re-colours:** the hovered mark keeps its paint and the rest dim. **Anything coloured reads itself out:** discrete marks show a tooltip with value, label in context and a swatch; one swatch component for every legend; one gradient definition for every SVG gradient.
- Deliberate identity colours (per-agent tints, per-source hues) stay outside the system, listed in one place.
- Container queries resolve against the card's content box: write breakpoints in those terms.

## Icons

- One icon set per app (lucide unless the product already chose another). One size scale: 16 px default, 14 px tight, 20/24 px emphasis; one stroke width. Match neighbours.
- A loading glyph is the set's spinner with `animate-spin`, never a bespoke svg.
- The assistant's mark is one component, never a sparkles icon or an asterisk sprinkled ad hoc.

## Dark mode and contrast

- Dark mode is first-class: check it every time. Tokens are what make it hold.
- Text contrast ≥ 4.5:1 for body and small text in both themes; run axe or an equivalent spec. Light-theme success, warning and gold text is the usual failure: give them darker light-mode tokens (or dedicated text tokens) rather than lowering the bar.
- Count text on an active tab is a common miss (faint on an active background); use the muted tone there.
- Knock-out white labels inside a bar vanish on light once the bar shrinks past the text: check both themes at the smallest value.
- SVG work needs a WebKit screenshot too: CSS filter functions do not apply to SVG elements in WebKit, and document CSS may not reach `<mask>` content.

## When the user names a colour

They mean what they see on screen, not the token name. "Primary blue" may mean the cyan of a word in the heading, not `--primary`. Map the request to a visible element, confirm the hex in the computed style, then change the right token.
