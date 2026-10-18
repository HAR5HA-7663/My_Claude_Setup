# Honest states and copy

## Honest UI: never show a state the system is not in

Every async surface has three states, built from the same component family as the loaded state:

- **Loading:** a skeleton shaped like the real content (rows, cards, a chart frame). Never a bare centred spinner for a list. A pending block holds its loaded size (see motion.md, first load).
- **Empty:** contextual. "No loans match your search" (with a clear-filters action) is different from "No loans yet" (with the first action). It fills its pane, centred. It never looks like loading.
- **Error:** a card that says what failed, with Retry. Never an infinite spinner. **A failed read never renders as "no data".**

Rules:

- **Loading never shows false data.** A list of switches that reads "all off" for a second while loading is a lie. Show the skeleton or hold the last known value.
- **Never fabricate data.** An unmeasured metric shows "—" (a zero is a claim). A value the source does not compute is an honest empty, not an invented percent.
- **No sample or demo data on a real screen.** Where the system is not connected yet, show a quiet not-connected notice (icon, one-line title, one-line description, optional action). Never a sample row, a fake "Verified" tag or a switch that reads ON where nothing is connected.
- **Never show an action as done when it was not.** A text never looks sent, a save never looks saved, until the server says so. Optimistic updates roll back visibly with a toast on failure.
- Disabled, done and failed states are designed, not leftovers: a disabled control says why (see interaction.md).
- Mocks are fine while building the UI first; delete them before the PR. Sample data visible to customers blocks the merge.

## Copy: short, plain, white-labeled

- **No vendor or internal system names in anything user-facing.** No database, provider, dialer, CRM or proxy names; no codenames of internal tools. The product is white-labeled. Record any deliberate exception (for example a payment processor's "Secured by" line on payment surfaces) in one place, with who approved it, and never extend it.
- **No em dashes.** Rewrite with a full stop, a comma, a colon or parentheses. (A lone "—" as the empty-value placeholder in a table cell is a glyph, not copy.)
- **No AI filler, no corporate jargon, no hype, no exclamation marks.** Plain sentences, direct, founder-to-founder.
- **Action labels are verbs:** "Add loan", "Send request", "Export CSV".
- **No explainer paragraphs.** A page subtitle is one functional line ("Every branch by stage, for any window."). No hint paragraph restating the table, no filler tagline, never a sentence about what is *not* shown ("Other branches are not shown here."). A number or rule that genuinely needs explaining gets one "?" tooltip beside its label holding the formula in a line.
- A "coming soon" placeholder is a promise, not a feature: leave it out.
- **Errors say what failed and what to do.** Never "An error occurred." Refusals are one plain sentence that names the missing permission by its label, never by its key.
- **No engineer language on screen:** env vars, keys, scopes, grants, ids, status codes.
- Copy lives in the area's config module, not at call sites, so a sweep finds it and tests can pin it.
- Name things consistently: one term per concept across header, page, buttons and toasts (if the header says "Log In", the page title, button and menu say it too).

## Copy sweeps

Source holds apostrophes three ways (`'`, `’`, `&apos;`), so a grep for `won.t route` misses `won&apos;t`. Grep `won('|’|&apos;|&#39;)?t`, or grep the concept words instead of the contraction. Do the same for quotes and dashes (`—`, `&mdash;`, `&#8212;`).
