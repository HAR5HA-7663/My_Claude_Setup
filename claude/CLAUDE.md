# Global CLAUDE.md

Loaded at the start of every Claude Code session on this machine.

## Personal Brain — LLM Wiki + Vector Layer

Harsha maintains a persistent LLM Wiki at `~/brain/`. It has three layers: **brain_wiki** (synthesized markdown pages + Chroma vectors), **brain_raw** (raw source drops + Chroma vectors), and the **watcher daemon** keeping vectors in sync with disk. The whole system is **Graphify** (Andre's name — not a separate layer).

At session start, `index.md` + `overview.md` are **auto-injected into context by the `SessionStart` hook** (runs `~/brain/scripts/session_context.sh`) — you normally do NOT need to read them manually. If they are somehow missing from context, load them yourself:

- `~/brain/wiki/index.md` — master catalog of all wiki pages.
- `~/brain/wiki/overview.md` — high-level synthesis.

**Do not** load every page under `~/brain/wiki/pages/` eagerly. Drill into specific pages only when the current task needs them.

### Structure

```
~/brain/
├── raw/              # drop zone — user writes here; assistant is READ-ONLY (policy)
├── wiki/
│   ├── index.md
│   ├── overview.md
│   ├── log.md        # append-only
│   └── pages/        # one file per concept / entity / topic
├── assets/           # binary attachments referenced by pages
├── scripts/          # Python layer: embed, watch, query, status, reembed_all
├── .chroma/          # Chroma persist (git-ignored)
└── .venv/            # Python env (git-ignored)
```

### Query priority (always in this order)

When answering any question Harsha might have covered in the brain:

1. **brain_wiki first** — run `/brain-query` (semantic over synthesized pages). Pre-synthesized, cheapest, highest precision.
2. **brain_raw fallback** — `/brain-query` auto-falls through to raw chunks when the wiki top score is below the gate (0.45 for OpenAI embeddings; tuned in `scripts/config.py`).
3. **Training memory last** — only when the script returns `in_brain: false` / `verdict: "not_in_brain"` (top score below `TRAINING_FALLBACK_FLOOR`, 0.40). Trust the script's verdict — don't re-threshold. Label the answer `[NOT IN BRAIN — training data]` on its own line.

**Always report which layer answered**, verbatim:
- `Answered from: brain_wiki (score 0.82)`
- `Answered from: brain_raw (score 0.71)`

**Never Grep/Glob over `~/brain/` if the brain has the answer.** The point of the vector layer is to replace literal search.

### Hard Rules

- **`raw/` is write-protected for the assistant** (policy, not filesystem). Never generate content into `raw/`. Only read.
- **`log.md` is append-only.** Never edit or delete existing entries.
- **Every new wiki page must have:** `title`, `last_updated`, `tags`, and at least one `[[cross-reference]]`.
- **Citations required.** When answering from the brain, cite the page slug (`[[slug]]`) or raw filename.
- **No silent overwrites.** When new info contradicts an existing page, surface the contradiction under a `## Contradictions` heading.
- **Never bypass `/brain-status`'s warnings.** If a collection shows mixed `embedding_models`, refuse to query until `reembed_all.py --wipe` has run — results will be garbage.

### Privacy

`BRAIN_PRIVACY_STRICT=1` in `~/brain/.env` blocks OpenAI embeddings — scripts fail closed at import time. Check `/brain-status` to see active mode and provider. If strict is on and `EMBED_MODEL` is still an OpenAI model, the status line is flagged fatal and scripts refuse to run until reconciled.

### Jev judgement layer (added 2026-09-21)

`scripts/jev.py` calls TypeSafe's hosted Jev decision model (key: `with-env --only TYPESAFE_API_KEY`). Three advisory uses, each falling back to the old behaviour on any failure: `query.py` reranks only when the top cosine score is ambiguous (`verdict_source: "jev"`, plus a `confidence` field — `low` means read the full pages before answering); `scripts.ingest_check` flags contradictions and sensitive content before an ingest; `scripts.staleness` replaces the flat 90-day lint rule. **All Jev use is disabled under `BRAIN_PRIVACY_STRICT=1` or `BRAIN_JEV=off`, and any page tagged `private` in its frontmatter is never sent.** Retrieved passage text does go to TypeSafe when it is consulted — tag sensitive pages `private`.

### Commands / Skills

- `/wiki-ingest` — process a file from `raw/` into wiki pages; embeds into `brain_wiki`.
- `/wiki-query` — literal slug lookups in the wiki (for when you already know the slug).
- `/wiki-lint` — health check on the wiki markdown (orphans, broken links, stale pages).
- `/wiki-save` — file a synthesized answer as a new wiki page and embed into `brain_wiki`.
- `/brain-query` — semantic two-tier retrieval (wiki → raw). Use this for any non-slug question.
- `/brain-status` — vector store + watcher health + consistency checks.

Skill definitions live in `~/.claude/skills/{wiki-ingest,wiki-query,wiki-lint,wiki-save,brain-query,brain-status}/SKILL.md`.

### Daemon

A launchd agent `com.harsha.brain-watch` at `~/Library/LaunchAgents/com.harsha.brain-watch.plist` runs `scripts/watch.py` — auto-embeds any `*.md` change under `raw/`, `wiki/pages/`, and `wiki/{index,overview}.md`. Debounces 2 s per path. Hash-deduplicated: unchanged files short-circuit. Logs to `~/brain/scripts/watch.log`.

Manage:
```
launchctl load   ~/Library/LaunchAgents/com.harsha.brain-watch.plist
launchctl unload ~/Library/LaunchAgents/com.harsha.brain-watch.plist
launchctl list   | grep brain-watch
```

### Filesystem Access

`~/brain/` is exposed globally via the `brain-fs` filesystem MCP server (user scope), so these rules apply across all Claude Code sessions regardless of working directory.

## Subagent & Workflow Model Tiering — DEFAULT BEHAVIOR

When authoring any Workflow script or spawning agents via the Agent tool, tier the model to the task instead of letting every subagent inherit the session model (Harsha's standing instruction, 2026-07-08):

| Tier | Use for | How |
|---|---|---|
| **haiku** | Pollers/watchers (CI checks, deploy waits), status-column flips, file moves, any mechanical loop | `agentType: 'poller'` (user-scope agent, model pinned) or `model: 'haiku'` |
| **sonnet** | Scripted single steps: open a PR with a written body, scripted browser QA, Monday/Slack comments with provided content | `agentType: 'scripted-runner'` or `model: 'sonnet'` |
| **inherit (fable/opus)** | Judgment-heavy work: root-causing, adversarial verification, code review, synthesis | omit `model` |

- Pair mechanical stages with `effort: 'low'` regardless of model.
- The pinned-model agent definitions live at `~/.claude/agents/poller.md` and `~/.claude/agents/scripted-runner.md` — prefer `agentType` over raw `model` overrides so the safety rules baked into those definitions apply too.
- Forks always inherit the parent model; custom agent types keep their frontmatter model.

## Jev Decision Layer — hooks, triage, screening (2026-09-21)

`jev-ask` (`~/.local/bin`) is the one-shot CLI every piece below uses: state on stdin, typed questions as flags, hard deadline, secret masking, `JEV_OFF=1` kill switch, `[[jev:private]]` marker refuses to send, circuit breaker, log at `~/.local/state/jev/jev.log` (timing only, never content). Everything is **advisory and fails open**: no key / timeout / outage means the pre-Jev behaviour.

- **Bash risk gate** (`~/.claude/scripts/jev-bash-risk-gate.sh`, PreToolUse Bash, after the regex guards): read-only commands are recognised locally and never sent; others get one ~0.45 s judgement. **deny** = confident exfiltration / security downgrade / shared-branch history rewrite or p(risky) ≥ 0.85; **ask** = sudo (always), curl-pipe-to-shell, non-disposable deletes, p(risky) ≥ 0.6. When it denies, do not rephrase the command to slip past it — explain what you need and let Harsha run it. Log: `~/.local/state/jev/bash-gate.log`. Tune: `~/.config/jev-gate.env` (`DENY_P`, `ASK_P`, `GATE_OFF=1`).
- **PR babysitter** now runs `jev-pr-risk.sh` on `gh pr create`: PRs touching shared billing / schema / auth-RBAC / deploy config are announced but **auto-merge is not armed**; the Slack line must say so. Never arm it yourself on a flagged PR.
- **Daily brain sync** runs `scripts.session_triage` first (knowledge 0–3, area, sensitive, decisions per transcript); empty sessions are skipped, sensitive ones get the careful path. `JEV_TRIAGE=0` disables.
- **loopengg**: `jev-verify-report --task "…" < report` before spending an opus skeptic (reject / verify / accept). Never a substitute for the skeptic on prod, billing, auth or data.
- **Job applicator**: archived 2026-09-22 (rarely used) at `~/.claude/skills-archive/job-applicator/`; `scripts/screen_postings.py` still works from there if job hunting resumes.
- **Skills** `/morning-triage` (Slack + SMS → Jev → drafts, never sends; launchd 08:30 headless, digest in `~/Desktop/morning-triage/`) and `/monday-triage` (BMYT board hygiene, report only; launchd Mondays 08:00, `~/Desktop/monday-triage/`).
- **Compaction prunes instead of summarising** (since 2026-09-23: the `jev-compact` plugin, source `~/Desktop/Personal/jev-compact`, repo `HAR5HA-7663/jev-compact`; `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1` lives in `~/.claude/settings.json` `env` so every launcher — terminal, desktop app, `claude agents` daemon — gets it; the plugin reads the key from `~/.env` itself). A session that shows no `[jev-compact …]` note after compaction was started before 2026-09-24 or without the flag — the plugin cannot be injected into a running session; restart it. `/compact` and auto-compact (75 %) are unchanged for Harsha. Old exploration outputs (Read/Grep/read-only Bash/snapshots) become one-line stubs, long tool inputs are shortened, hook noise is stripped, Jev ranks the remaining judgement calls against a 45 % budget; all user/assistant text, errors and failing tests stay verbatim. A `[jev-compact …]` note near the top lists what was removed — **re-run a tool rather than recall a pruned output**. Falls back to the built-in summary when pruning cannot reach the budget (`hybrid` in `~/.local/state/jev/compact.log`). Removed outputs land in `~/brain/archive/compaction/<date>/` for the daily sync. Opt out: `JEV_COMPACT_OFF=1`, a `.jev-compact-off` file, or `[[jev:private]]`; `claude-plain` launches without function hooks.
- **Privacy:** command text, diffs, transcript condensations, messages, tickets and postings go to TypeSafe's hosted API (secrets masked). Nothing from `[[jev:private]]`-marked state, nothing when `JEV_OFF=1`.

## Universal Env File — `~/.env` via `with-env`

All of Harsha's API keys live in **`~/.env`** (mode 600), grouped into owner blocks: **`[personal]`, `[bevri]`, `[teli]`, `[fsbo]`, `[other]`** (any new `[block]` header works). It is loaded **on demand only** — never sourced from `.zshenv`/`.zshrc`, so normal shells and their child processes do not see the secrets (deliberate: this machine has a malware history). Set up 2026-09-21.

- **Same product, different company:** the same NAME (e.g. `STRIPE_SECRET_KEY`) can exist in several blocks. `with-env` always hands it to the command under its plain NAME, so tools work unchanged — the block decides *whose* key it is.
- **Pick the block from the work, not from convenience.** Bevri task → `--scope bevri`, Teli → `--scope teli`, FSBO → `--scope fsbo`. Never substitute another company's key because the right block is empty — stop and ask Harsha to add it. A name that exists in more than one block errors without `--scope` (by design, never guessed).
- **See what exists:** `with-env --blocks [--scope S]` (blocks + key counts), `with-env --list [--scope S]` (names only), `with-env --has NAME [--scope S]`. Check here before asking Harsha for a key.
- **Use a key:** `with-env --scope bevri --only NAME[,NAME2] <cmd>`. Lookup order: the exact `[bevri]` block → project blocks `[bevri/...]` → scratch copies (`tmp/`, worktrees). Within a step every block holding NAME must agree on the value, otherwise it errors and lists the blocks — then pass the exact block (`--scope bevri/api-backend`). It prints `NAME <- [block]` on stderr: **read that line** to confirm which repo/rig supplied the value (wrong-DB hazard). It never crosses owners. `--scope <exact block>` with no `--only` loads that whole block; loading every block at once is refused. Variables expand in the child shell, so wrap references: `with-env --only TYPESAFE_API_KEY sh -c 'curl -H "Authorization: Bearer $TYPESAFE_API_KEY" ...'`.
- **Scripts / hooks / launchd jobs** that need a key call `with-env` themselves (`~/.local/bin/with-env`) — they do not inherit it.
- **Never print values.** Do not `cat`/Read `~/.env`, `echo` a variable, run `env`/`printenv` under `with-env`, or use `curl -v` with an auth header. Values must not land in the transcript.
- **New keys:** Harsha adds a `NAME=value` line under the right block in `~/.env` himself and tells you the block + name. If he pastes a secret in chat anyway, append it to `~/.env` without echoing it and remind him that it is now in the transcript and should be rotated.
- **Never copy these into `~/.claude/settings.json`'s `env` block** (or anything else under `~/.claude/`) — that tree is published to the public `My_Claude_Setup` repo.
- **Project `.env` files are mirrored, not moved.** `env-sync` (`~/.local/bin/env-sync`, `--dry-run` to preview) scans the whole home dir and copies every real `.env` / `.env.*` / `*.env` into an `[owner/path-to-repo]` block inside that owner's section of `~/.env` (`@local` = `.env.local`; identical copies deduped; examples/templates skipped; scratch copies listed last in each section). The project file stays the source of truth because the apps read it — **never delete or edit a project `.env` as part of this, and never hand-edit a block that has a `# source:` line** (regenerated every run); change the project file and re-run `env-sync`. Run `env-sync` after adding or changing a project `.env`. Several mirrored blocks are QA/demo rigs (`bevri/tmp/*`, worktrees) — check the `# source:` path before assuming a block is prod or local.
- Blocks without a `# source:` line (`[personal]`, `[bevri]`, `[teli]`, `[fsbo]`, `[other]`, anything Harsha adds) are hand-edited, preserved by `env-sync`, and exist nowhere else; `~/.env.bak` is the previous version, written on every sync.
- **Never open `~/.env` with Read or print it unmasked** — it now holds ~500 live secrets. To inspect structure: `sed -E 's/^([A-Za-z_][A-Za-z0-9_]*)=.*/\1=•••/' ~/.env`.
- `with-env` fails closed if `~/.env` is not mode 600/400.

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

## Harsha's Writing Style — Use for ALL Messages Drafted as Him

Full guide: `/Users/HAR5HA/brain/assets/harsha-slack-writing-style.md` (derived 2026-06-10 from ~25 of his hand-typed Slack messages). Applies in every project/session whenever drafting a Slack message, DM, thread reply, or any text to be sent as Harsha.

- Casual, direct, friendly: "bro", "brother", "guys", "hey", "hi guys"; names lowercase ("chelle", "jon").
- Mostly lowercase including "i"; run-on sentences, light punctuation, no bullets/bold/headers in hand-typed messages; occasional "??" or space before "?".
- His phrasings: "can you once check it out", "explain me", "correct me if i am wrong here", "will let you know once done", "sorry for the extra work but...".
- Flows with plain arrows: "create a brand -> verified -> buy number -> campaign".
- Technical deep-detail = casual hand-typed intro line + polished body in a code block (that's his authentic pattern for pasting specs/root-causes).
- Do NOT apply to code, commits, PRs, or docs — those stay normal/professional.
- A Claude-sounding draft (bold headers, em-dashes, "Short version:") reads as fake — rewrite it in his voice before drafting on his behalf.
