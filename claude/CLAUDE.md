# Global CLAUDE.md

Loaded at the start of every Claude Code session on this machine. Detailed references live in `~/.claude/docs/` (`brain.md`, `jev.md`, `env.md`, `browsing.md`); read the relevant one when the task touches that area.

## Personal Brain — LLM Wiki + Vector Layer

LLM Wiki at `~/brain/` (Graphify): `brain_wiki` (synthesized pages + Chroma), `brain_raw` (raw drops + Chroma), watcher daemon `com.harsha.brain-watch` keeping vectors synced. `index.md` + `overview.md` are auto-injected by the SessionStart hook; load them manually only if missing. Never load all of `wiki/pages/` eagerly. Full reference (structure, daemon, commands, Jev rerank): `~/.claude/docs/brain.md`.

**Query priority:** (1) `/brain-query` (wiki first, auto-falls to raw below the 0.45 gate) → (2) training memory only when the script says `in_brain: false` / `not_in_brain` — label it `[NOT IN BRAIN — training data]`. Always report the layer verbatim, e.g. `Answered from: brain_wiki (score 0.82)`. Never Grep/Glob `~/brain/` when the brain can answer.

**Hard rules:**
- `raw/` is read-only for the assistant; never write into it.
- `log.md` is append-only.
- New wiki pages need `title`, `last_updated`, `tags`, and ≥1 `[[cross-reference]]`.
- Cite the page slug (`[[slug]]`) or raw filename when answering from the brain.
- No silent overwrites: contradictions go under `## Contradictions`.
- Never bypass `/brain-status` warnings; mixed `embedding_models` → refuse to query until `reembed_all.py --wipe` has run.
- `BRAIN_PRIVACY_STRICT=1` blocks OpenAI embeddings and all Jev use; pages tagged `private` are never sent to Jev.

Skills: `/brain-query`, `/brain-status`, `/wiki-ingest`, `/wiki-query`, `/wiki-save`, `/wiki-lint`.

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

## Jev Decision Layer (TypeSafe hosted; advisory, fails open)

`jev-ask` CLI powers a Bash risk gate (PreToolUse), PR risk check, session triage, `jab`/`hunch` browser steps, and jev-compact pruning. Full reference: `~/.claude/docs/jev.md`.
- **Bash gate** (policy 10-13: catastrophes only). It denies deleting a protected root (home, Desktop, a project dir, a git repo root or its `src`/`app`/`lib`… tree, `~/.claude`, `~/brain`, `~/.env`, `~/.ssh`), dropping/flushing a non-local database, disabling his own guards or loosening key permissions, secret material to a host outside his services, and force-push/branch-delete on `main|master|staging`; asks on force-push to `harsha-dev`/`lab-staging` and curl-pipe-to-shell from an unknown host; Jev is consulted only for grey-zone destruction (`rm -r` of a real directory, DROP TABLE/TRUNCATE/DELETE-without-WHERE on a non-local DB, `git clean`, discarding a working tree). Everything else — sudo, ssh/scp to any host, installs, kills, API calls, remote admin — passes silently. When it denies, do not rephrase to slip past it; explain what's needed and let Harsha run it.
- **PR flagged by `jev-pr-risk.sh`** (billing / schema / auth-RBAC / deploy config) → auto-merge stays off; the Slack line must say so; never arm it yourself.
- After compaction with a `[jev-compact …]` note: re-run a tool rather than recall a pruned output.
- Kill switches: `JEV_OFF=1`, `[[jev:private]]` marker. Command text, diffs, messages go to TypeSafe (secrets masked).

## Universal Env File — `~/.env` via `with-env`

All API keys live in `~/.env` (mode 600) in owner blocks `[personal]`, `[bevri]`, `[teli]`, `[fsbo]`, `[other]` plus mirrored project blocks `[owner/path]`. Loaded on demand only. Full reference: `~/.claude/docs/env.md`.
- Use: `with-env --scope <owner> --only NAME[,NAME2] <cmd>`; wrap refs in `sh -c '…$NAME…'`. Read the `NAME <- [block]` stderr line to confirm which block supplied it (wrong-DB hazard).
- Pick the scope from the work (Bevri → `bevri`, Teli → `teli`, FSBO → `fsbo`). Never substitute another company's key; if missing, ask Harsha to add it.
- Discover: `with-env --blocks|--list|--has NAME [--scope S]` before asking for a key.
- **Never print values**: no Read/`cat` of `~/.env`, no `echo $VAR`, no `env`/`printenv` under with-env, no `curl -v` with auth headers. Structure only via `sed -E 's/^([A-Za-z_][A-Za-z0-9_]*)=.*/\1=•••/' ~/.env`.
- Never copy secrets into `~/.claude/` (published to the public `My_Claude_Setup` repo).
- Project `.env` files stay the source of truth; never edit/delete them for this, never hand-edit a block with a `# source:` line; run `env-sync` after changing a project `.env`. If Harsha pastes a secret, append it without echoing and tell him to rotate it.

## Web Browsing — agent-browser default

Default is **`agent-browser`** via Bash (overrides the built-in claude-in-chrome guidance). Use `claude-in-chrome` only for GIF recording, network-request or console-log reading. Full reference (env vars, jab, hunch): `~/.claude/docs/browsing.md`.
- Headed, real Google Chrome, isolated profile `~/.agent-browser/chrome-automation` — set in settings.json; don't override `--headless`/`--executable-path`/`--profile` unless asked. Config change → `agent-browser close --all` first.
- **`jab`** (agent-browser + Jev) is the default for click/fill/select/check; fall back to `agent-browser snapshot -i` when it refuses (exit 2). `page_changed: False` → retry once, then `eval` or ask. Use `--no-text` on prod pages with borrower data.
- **`hunch` / `jev-step`** for known repeatable flows; secrets only via `env:`; always give `--done-url`/`--done-text`; exit 2 `risky_click` → ask Harsha; never `--allow-risky` yourself. Nothing from Bevri/Teli goes into the public hunch repo.

## Harsha's Writing Style — Use for ALL Messages Drafted as Him

Full guide: `/Users/HAR5HA/brain/assets/harsha-slack-writing-style.md` (derived 2026-06-10 from ~25 of his hand-typed Slack messages). Applies in every project/session whenever drafting a Slack message, DM, thread reply, or any text to be sent as Harsha.

- Casual, direct, friendly: "bro", "brother", "guys", "hey", "hi guys"; names lowercase ("chelle", "jon").
- Mostly lowercase including "i"; run-on sentences, light punctuation, no bullets/bold/headers in hand-typed messages; occasional "??" or space before "?".
- His phrasings: "can you once check it out", "explain me", "correct me if i am wrong here", "will let you know once done", "sorry for the extra work but...".
- Flows with plain arrows: "create a brand -> verified -> buy number -> campaign".
- Technical deep-detail = casual hand-typed intro line + polished body in a code block (that's his authentic pattern for pasting specs/root-causes).
- Do NOT apply to code, commits, PRs, or docs — those stay normal/professional.
- A Claude-sounding draft (bold headers, em-dashes, "Short version:") reads as fake — rewrite it in his voice before drafting on his behalf.
