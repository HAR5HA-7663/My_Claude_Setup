# Interaction, permissions and configurability

## Contents
- Permissions, never roles
- Configurable over hardcoded, with a reset
- Per-user UI state
- Explicit over automatic
- Real links and the back trail
- Keyboard
- Reordering
- Prompt, don't gate
- Previews and minor actions
- Destructive actions

## Permissions, never roles

- UI decides capability by a **permission key**: `useCan('leads.export')`, `<Can perm="leads.export">`, or `can(key)` in handlers. Never `role === 'admin'`. Role names are display data, or data in a seat assignment, each allowlisted with a reason.
- Roles are editable bundles of keys. Scopes (branches, teams, workspaces) scope records and grant nothing.
- One permission catalogue: keys, groups, labels, descriptions, and the role bundles. Add the key there first.
- A control the person cannot use is **absent, or disabled with the reason** (a reason line under the section, or the reason inside the menu item). Refusals are one sentence naming the permission by its label.
- Commands recheck the permission at execution time. A permitted preview does not authorise an action after access changes.
- To pick people ("who to notify"), select permission holders, never a role name.
- Lock it: a test or gate rule that fails on a new role literal.

Starting with roles and migrating to permissions later is one of the most expensive mistakes a product can make. Start with permissions.

## Configurable over hardcoded, with a reset

- Anything a user might want to change comes from a **registry** plus a **persisted preference**: nav order and visibility, filters, saved views, columns and their order, sort, pane sizes, window positions, dashboard widgets and their order, density, theme, an assistant's position.
- Registries are one typed `as const` file per area (nav, stages, statuses, columns, filter fields, presets, widgets, templates, tabs). Read them through a hook (`useRegistry(key)`), never as literals in JSX.
- **Every preference has a reset**, plus "Reset all preferences" in Settings. Defaults are understandable.
- A "Customize" affordance in the standard header exposes a screen's switches, order and resets in one body.
- Never hardcode one customer's field, label or threshold into global logic. Build the admin mapping UI instead.
- Sharing a preset needs its own permission. A preset carries presentation, never access.

## Per-user UI state

- **One prefs store** holds every per-user ergonomic setting: one query per session, a localStorage mirror where the freshest timestamp wins, debounced best-effort upsert, flush on tab hide. Dot-namespaced keys (`panels.<surface>`), size limits enforced. Never add a special-purpose prefs table.
- **Sorts** go through one hook: URL `?sort=` (which also overwrites the pref) beats the saved pref beats the default. Ties resolve most-recent-first, nulls last.
- **Page-level view choices** (board axis, list/board toggle, any small enum) go through the enum twin of that hook: URL > pref > default; an explicit choice records (deep links too), landing on the default records nothing, so changing a default reaches old visitors.
- **Saved views save filters only** (see components.md, filters).
- In drives and tests, remembered prefs leak between runs: set each explicitly instead of assuming the default, and clear the prefs before a suite.

## Explicit over automatic

The UI never silently acts for the user: no auto-applied guessed values, no controls that vanish, no auto-layout without asking. Offer the action, apply it on a click, and give an undo.

## Real links and the back trail

- **Anything a person opens is a real link** (`<a href>`), so cmd-click, middle-click, drag to the tab bar and "Open in new tab" work. Never `onClick={() => navigate(...)}` on rows, cards or cross-links.
- A clickable row stays a `div` host; a **stretched, contentless anchor** covers it, and CSS lifts every interactive descendant above the anchor so cells keep their own buttons and menus (an interactive element inside an anchor is invalid and swallows clicks). Give the anchor an accessible name ("Open loan for Jane Doe").
- A row that opens a dialog, not a page, uses the same stretched pattern as a `<button>`. Do not keep a separate Edit button beside a clickable row; the row is the way in.
- A plain click is still client-side navigation with state; the href carries the context (workspace, acting scope) so a new tab lands in the same place.
- **Back buttons ride a back trail**, never a hard-coded list path: cross-surface links push the current location (pathname + search) onto a bounded, loop-deduped stack in router state; the detail page's back button pops it and is labelled "Back to <surface>". Lists get their filters back.
- Navigate on mount from `useEffect`, never `useLayoutEffect` (react-router 7 drops calls made before its own layout effect arms it, silently in production).

## Keyboard

- Container activators (rows, cards and tiles with `role="button"`) act on Enter/Space only when `event.target === event.currentTarget`. React synthetic events bubble through the component tree, so a portaled panel's keydown can "click" the row hosting its trigger.
- Never blanket-`stopPropagation` keydowns at a panel; it breaks the window-level Escape stack. Overlays own Escape through the layer registry.
- One commit-keys helper for inline editors (Enter commits, Escape cancels).
- Tabs use manual activation: arrows move focus, Enter/Space or click switch, and focus moved by code never switches the tab.
- Visible focus rings everywhere; tab order follows reading order.

## Reordering

- **Reordering is drag-and-drop with keyboard support.** A grip handle, a pointer sensor with a small activation distance (~5 px) and a keyboard sensor. Chevron up/down button pairs are not shippable.
- Where a dragged item lands is arithmetic, not the DnD library's job: keep it in a pure helper with its own tests.
- Apply the drop optimistically; roll back and toast on failure. Persist the order.
- Use one drag overlay that portals to `body` (a scene mid-transition would otherwise become the fixed overlay's containing block) and carries the token drop animation.

## Prompt, don't gate

New required work (a form, a checklist, a packet) never becomes a precondition of an existing action. Leave the action live and put the new step in the slot of the next thing owed, as a prompt with a deep link that disappears once done; never a disabled button or a redirect. Check when the artifact is actually due. When an explicit requirement does gate, the gate is a live button that opens the missing fields in place.

## Previews and minor actions

- **Preview what the input produces** using the real consuming component, never a lookalike: a link field shows the link card, a video field the player, a template the rendered message.
- User-authored links render at read time; storage stays plain text, and only http(s) hrefs render.
- **Minor actions go in the kebab menu**, not a new CTA button. One primary action per region.

## Destructive actions

- The button arms on the first click and becomes Cancel; a separate confirm control ignores clicks for ~800 ms after it appears, so a double-click cannot confirm by accident. Or use the house confirm dialog with the thing at stake in bold.
- Name what will happen ("Deletes 3 drafts. Sent texts stay.").
- Prefer undo over confirm where the action can be reversed.
