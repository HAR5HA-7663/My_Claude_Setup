# Personal Brain — full reference

> Moved out of `~/.claude/CLAUDE.md` on 2026-10-06 to keep it small. CLAUDE.md keeps the hard rules; this is the full reference.

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

