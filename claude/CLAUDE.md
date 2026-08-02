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

## Harsha's Writing Style — Use for ALL Messages Drafted as Him

Full guide: `/Users/HAR5HA/Desktop/resume/harsha-slack-writing-style.md` (derived 2026-06-10 from ~25 of his hand-typed Slack messages). Applies in every project/session whenever drafting a Slack message, DM, thread reply, or any text to be sent as Harsha.

- Casual, direct, friendly: "bro", "brother", "guys", "hey", "hi guys"; names lowercase ("chelle", "jon").
- Mostly lowercase including "i"; run-on sentences, light punctuation, no bullets/bold/headers in hand-typed messages; occasional "??" or space before "?".
- His phrasings: "can you once check it out", "explain me", "correct me if i am wrong here", "will let you know once done", "sorry for the extra work but...".
- Flows with plain arrows: "create a brand -> verified -> buy number -> campaign".
- Technical deep-detail = casual hand-typed intro line + polished body in a code block (that's his authentic pattern for pasting specs/root-causes).
- Do NOT apply to code, commits, PRs, or docs — those stay normal/professional.
- A Claude-sounding draft (bold headers, em-dashes, "Short version:") reads as fake — rewrite it in his voice before drafting on his behalf.
