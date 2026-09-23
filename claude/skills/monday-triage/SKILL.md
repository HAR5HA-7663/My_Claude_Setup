---
name: monday-triage
description: Ticket hygiene for the Bevri BMYT board (or any Monday board / GitHub issue list). Exports the open tickets, lets Jev score severity, area, bug-vs-feature and missing repro steps, finds duplicate pairs within each area in one request, and produces a report with draft comments in Harsha's voice. Use when the user says "/monday-triage", "triage the board", "find duplicate tickets", "which tickets are missing repro steps". Report only; comments are posted only when Harsha approves each one.
---

# monday-triage

## Steps

1. **Export.** Find the board (default: the BMYT board — `mcp__monday__search` for
   "BMYT" if the id is not known) and page through open items with
   `get_board_items_page`. Write `~/Desktop/monday-triage/.tickets-YYYY-MM-DD.json` as a
   list of `{"id","title","body","status","area","owner","created"}` (body = description +
   latest update text, first 1500 chars).

2. **Score.**
   ```
   python3 ~/.claude/scripts/jev-triage-tickets.py ~/Desktop/monday-triage/.tickets-YYYY-MM-DD.json --json
   ```
   Gives per-ticket `severity` 0–3, `area`, `is_bug`, `missing_repro`, `needs_repro`, plus
   `duplicates` (pairs with p ≥ 0.7, scored within each area) and `critical` (severity ≥ 2.5).

3. **Report** to `~/Desktop/monday-triage/YYYY-MM-DD.md`:
   - **critical** tickets first, with one line each on why.
   - **duplicate pairs** with the probability; propose which one to keep.
   - **needs repro** list, each with a draft comment in Harsha's voice asking for exactly
     what is missing, e.g. `hey can you add the steps + which account/env this was on, cant
     repro from the title alone`.
   - area counts.

4. **Post nothing on your own.** When Harsha says "post the repro comments" (or names
   ticket ids), post those with `create_update` and tick them off in the report. Duplicate
   closures are always his call.

## Rules

- Ticket titles and bodies go to TypeSafe's API. Borrower/customer PII inside a ticket body
  goes with it; if a board is known to carry PII, pass only titles (`"body": ""`).
- Weekly headless run (Monday 08:00, launchd `com.harsha.monday-triage`) produces the report
  only; it has no write tools.
