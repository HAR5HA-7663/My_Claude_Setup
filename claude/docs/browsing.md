# Web Browsing (agent-browser, jab, hunch) — full reference

> Moved out of `~/.claude/CLAUDE.md` on 2026-10-06 to keep it small. CLAUDE.md keeps the hard rules; this is the full reference.

## Web Browsing — agent-browser default

Default web-browsing tool is **`agent-browser`** (Vercel Labs native Rust CLI), driven through the Bash tool. The `agent-browser` skill documents the command set. This rule **overrides** the built-in MCP guidance that says to use `claude-in-chrome` for web tasks.

- **Default — `agent-browser`:** navigating pages, snapshots, clicking, form fill, scraping, web app testing, screenshots. Daemon persists between commands.
- **Fallback — `claude-in-chrome` MCP:** use only when the task needs GIF recording, network-request inspection, or console-log reading — capabilities `agent-browser` does not cover.
- Both remain installed; `claude-in-chrome` MCP config is unchanged.
- Backend: local bundled Chrome for Testing. No cloud browser provider configured.
- **Headed by default.** `AGENT_BROWSER_HEADED=1` is set in `~/.claude/settings.json` so the browser window is always visible — the user wants to watch the automation, not run it headless. Do not pass `--headless` or disable headed mode unless the user explicitly asks for a hidden / background run.
- **Real Google Chrome + dedicated automation user-data dir.** Two env vars are set in `~/.claude/settings.json`:
  - `AGENT_BROWSER_EXECUTABLE_PATH=/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` — uses the real installed Google Chrome (full profile chip, Google sync, real Chrome UI), not the bundled Chrome for Testing.
  - `AGENT_BROWSER_PROFILE=/Users/HAR5HA/.agent-browser/chrome-automation` — isolated Chrome user-data dir dedicated to automation. NOT a profile inside the user's daily Chrome user-data dir. Login state persists across runs here. The user's daily Chrome and its 5 work/personal profiles are never touched, never locked, never need to be closed.
  - Do not override either with `--executable-path` or `--profile` unless the user explicitly asks to use their daily Chrome or a different profile.
- If a daemon is already running with old options when a config change is needed, close it first: `agent-browser close --all` then re-open.
- **`jab` = agent-browser + Jev (added 2026-09-22). Default to it for the click/fill/assert loop; fall back to raw `agent-browser snapshot` only when it refuses.** Same daemon, same `--session`, same `@refs`. Each call is one snapshot + one ~200 ms Jev decision, so a step is one tool call instead of snapshot → read → act:
  - `jab click "<what, as a tester would say it>"` · `jab fill "<field>" "<value>"` · `jab select "<dropdown>" "<option>"` — Jev picks the ref; prints ref, label, confidence, `page_changed`. Refuses (exit 2) when the target isn't on the page or confidence < 0.7; then read `agent-browser snapshot -i` yourself.
  - `jab check "<statement>" ["<statement>"…]` — PASS/FAIL per statement from the live page (exit 2 on any FAIL). Use it for QA assertions instead of reading snapshots: "an error toast is visible", "the row for X exists", "the user is logged in", "this is staging not prod".
  - `jab snap "<goal>"` — the snapshot trimmed to elements that matter for the goal; read this instead of the full tree on big pages.
  - `jab do "<goal>" --value k=env:VAR --done-url REGEX` — a whole known flow (login, wizard) via hunch.
  - `page_changed: False` after a click means the click did not register (some React pages ignore Playwright clicks); retry once, then fall back to `agent-browser eval` or ask.
  - Values passed to `fill` never go to Jev; labels, URL path and up to 2.5 KB of page text do (`--no-text` sends labels only — use it on prod pages showing borrower data).

### hunch — Jev fast path for routine browser flows (added 2026-09-21)

`hunch` (alias `jev-step`; source `~/Desktop/Personal/hunch`, repo `HAR5HA-7663/hunch`) runs a browser goal on agent-browser with one Jev decision per step (~150 ms) instead of an LLM turn per step. Use it for known, repeatable flows — sign-ins, form fills, QA checklists — and take over with plain agent-browser only when it exits 2.

- `jev-step --session <job> --url <start> --goal "<literal instruction>" --value email=env:VAR --value password=env:VAR --done-url '<regex>' --quiet` (the wrapper pulls the Jev key from `~/.env`). Still isolate per job: `AGENT_BROWSER_SESSION` + `AGENT_BROWSER_PROFILE=~/.agent-browser/chrome-automation-<job>`.
- Secrets go in with `env:` only — value *names* reach Jev, never the text. Always give `--done-url`/`--done-text`; a model "done" is never trusted.
- Exit 2 = escalation with `reason`, `visible_text`, `history`, `elements`. `risky_click` means ask Harsha before clicking it yourself; never pass `--allow-risky` on your own.
- Element labels + up to 800 chars of page text go to TypeSafe (hosted). Fine for staging (PII-masked); use `--no-page-text` or skip hunch on prod pages showing borrower data.
- Verified 2026-09-21 on staging.bevri.ai login: 3/3 runs, median 3.5 s. **Nothing from Bevri/Teli may ever go into the public hunch repo** (no URLs, accounts, screenshots).

