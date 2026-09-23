# My_Claude_Setup

Full export of Harsha's Claude Code environment (first exported 2026-08-02; refreshed 2026-09-23 with `export.py`, from macOS, Claude Code 2.1.281). This repo lets a Claude Code agent on **any machine (macOS / Linux / Windows)** replicate the setup so it looks and functions the same.

> ## ⚠️ READ THIS FIRST — installing agent
>
> **Do NOT copy the whole `claude/skills/` folder. Do NOT install all 7 plugins.**
>
> Before installing anything you MUST show the user the skill catalog below and ask
> **which skills they actually need** — both the personal skills in this repo and the
> skills that arrive with each plugin. Install **only** what they pick.
>
> Nobody needs 44 personal skills + 73 plugin skills. Most of them are dead weight for a
> given person, and every installed skill costs context on every single session.
>
> Full procedure: [`INSTALL_AGENT.md`](INSTALL_AGENT.md). Machine-readable catalog:
> [`manifest.json`](manifest.json).

## Quick start on the new machine

1. Install prerequisites: `git`, `gh` (GitHub CLI), Node.js ≥ 18, and Claude Code itself
   (`npm install -g @anthropic-ai/claude-code` or the native installer).
2. `gh auth login` and clone this repo.
3. Open Claude Code in the cloned repo and tell the agent:

   > Read INSTALL_AGENT.md in this repo and install my Claude setup. Ask me which
   > components AND which individual skills I want first, then install exactly those.

## What's in here

| Path | Contents |
|---|---|
| `manifest.json` | Machine-readable catalog of every component + every skill (the installer's source of truth) |
| `INSTALL_AGENT.md` | Step-by-step instructions for the installing agent, incl. the selection UX |
| `claude/settings.json` | Model (`claude-fable-5[1m]`), effort `xhigh`, fullscreen TUI, dark theme, voice (hold mode), auto permission mode, hooks, statusline wiring, enabled plugins, env vars |
| `claude/settings.local.json` | Skill visibility overrides |
| `claude/CLAUDE.md` | Global instructions: personal brain rules, subagent model tiering, Jev decision layer, universal `~/.env`, agent-browser + `jab`/`hunch` default, writing style |
| `claude/skills/` | **44 personal skills** — see the catalog below. Sub-selectable; do not bulk-copy. |
| `claude/agents/` | `poller` (haiku-pinned) and `scripted-runner` (sonnet-pinned) custom agents |
| `claude/commands/` | `/clipboard`, `/council` slash commands |
| `claude/scripts/` | Hook + automation scripts (17): malware guards + IOC sync + daily host sweep, PR babysitter with Jev risk pre-filter, Jev Bash risk gate, verify-report, morning/monday triage runners, mem-guard, TCC residue cleaner |
| `bin/` | CLI tools the hooks and skills call: `with-env` / `env-sync` (universal `~/.env`), `jev-ask`, `jev-step`, `jab`, `jev-replicate` → `~/.local/bin/` |
| `launchd/` | macOS scheduled jobs: brain watcher + sync, daily brain sync, malware sweep, mem-guard, morning/monday triage (paths need rewriting) |
| `shell/zshrc-claude.zsh` | `claude` launcher with function hooks on (for jev-compact), `claude-plain`, `lawde` |
| `export.py` | Regenerates this repo from the live machine (copies, scrubs, rebuilds `manifest.json` + `mcp/`); `--check` = secret scan only |
| `claude/statusline-custom.sh` + `claude/statusline/` | Custom statusline (active) + claude-code-statusline package v2.24.0 |
| `mcp/mcp-servers.json` | User-scope MCP servers (secrets replaced with `<PLACEHOLDERS>`) |
| `extras/harsha-slack-writing-style.md` | Writing-style guide referenced by CLAUDE.md |
| `external-deps.md` | Things NOT in this repo that the setup depends on (brain, agent-browser, daemons) |

---

# Skills come from three different places

Know which bucket a skill is in before trying to install it.

| Source | Where it lives | How to install |
|---|---|---|
| **1. Personal** (44) | `claude/skills/` in this repo | Copy the chosen folders → `~/.claude/skills/` |
| **2. Plugin-provided** (73) | Not in this repo — ships inside a plugin | `/plugin install <plugin>@<marketplace>` |
| **3. CLI-provided** (1) | Not in this repo — ships with an external CLI | Install the CLI (see `external-deps.md`) |

## 1. Personal skills (44) — in `claude/skills/`

Ask the user which of these they want. Group headings are just for the conversation;
each folder is independent.

**Personal brain / wiki (6)** — *require `~/brain`, which is NOT in this repo. Skip all 6 if the user isn't restoring the brain.*
`brain-query` · `brain-status` · `wiki-ingest` · `wiki-lint` · `wiki-query` · `wiki-save`

**Orchestration & meta (4)**
`loopengg` (loop-engineering orchestration mode: decompose → fan out to model-tiered subagents → adversarially verify → report) · `council` (5-advisor adversarial decision panel) · `skill-creator` · `mcp-builder`

**Design & visual (17)**
`design` · `design-system` · `frontend-design` · `ui-styling` · `ui-ux-pro-max` · `motion-design` · `brand` · `brand-guidelines` · `banner-design` · `canvas-design` · `algorithmic-art` · `theme-factory` · `slides` · `web-artifacts-builder` · `slack-gif-creator` · `excalidraw` · `auto-diagram`

**GSAP animation (8)** — *only useful if the user writes GSAP animations; take all 8 or none.*
`gsap-core` · `gsap-timeline` · `gsap-scrolltrigger` · `gsap-plugins` · `gsap-react` · `gsap-frameworks` · `gsap-utils` · `gsap-performance`

**Documents & writing (6)**
`docx` · `pptx` · `xlsx` · `pdf` · `doc-coauthoring` · `internal-comms`

**Testing (1)**
`webapp-testing`

**Personal automation (2)** — *Jev-triage skills: need the Slack plugin / Monday MCP, `bin/jev-ask` and a TypeSafe key. Report-only, never send anything.*
`morning-triage` · `monday-triage`

## 2. Plugin-provided skills (73) — NOT in this repo

These do **not** exist in `claude/skills/`. They arrive when the plugin is installed, and
they disappear when it's uninstalled. Ask the user per plugin — "do you want these skills?"
— and install only those plugins.

| Plugin | Install | Skills it brings | Slash commands |
|---|---|---|---|
| **superpowers** | `/plugin install superpowers@claude-plugins-official` | 14 — `brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development`, `dispatching-parallel-agents`, `systematic-debugging`, `test-driven-development`, `verification-before-completion`, `requesting-code-review`, `receiving-code-review`, `finishing-a-development-branch`, `using-git-worktrees`, `using-superpowers`, `writing-skills` | — |
| **vercel** | `/plugin install vercel@claude-plugins-official` | 35 — Vercel / Next.js / AI SDK skills + 3 agents (`ai-architect`, `deployment-expert`, `performance-optimizer`) + the Vercel MCP server | 5 |
| **stripe** | `/plugin install stripe@claude-plugins-official` | 9 — Stripe API / Connect / billing skills + the Stripe MCP server | 2 |
| **slack** | `/plugin install slack@claude-plugins-official` | 8 — `slack-api`, `slack-cli`, `slack-docs`, `slack-search`, `slack-messaging`, `block-kit`, `create-slack-app`, … + the Slack MCP server | `/channel-digest`, `/draft-message`, … (5) |
| **caveman** | `claude plugin marketplace add JuliusBrussee/caveman` then `/plugin install caveman@caveman` | 4 — `caveman` (compressed comms mode), `caveman-commit`, `caveman-review`, `compress` | — |
| **codex** | `claude plugin marketplace add openai/codex-plugin-cc` then `/plugin install codex@openai-codex` | 3 — Codex hand-off skills + the `codex-rescue` agent | 8 |
| **jev-compact** *(Harsha's own)* | `git clone https://github.com/HAR5HA-7663/jev-compact`, `claude plugin marketplace add <clone dir>`, `claude plugin install jev-compact@jev-compact --config targetPercent=45 --config compactAtPercent=75 --config preserveRecentMessages=12 --config minReductionRatio=0.25 --config model=jev-1.13.0 --config brainArchive=true` | 0 — a function hook that replaces `/compact` with prune-not-summarise compaction. Needs `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1` (see `shell/`) and `TYPESAFE_API_KEY` in `~/.env` | — |
| *installed but disabled:* coderabbit, imessage *(macOS)*, swift-lsp *(macOS)* | `/plugin install …@claude-plugins-official` | 2 / 2 / 0 — turned off on the source machine; skip unless asked | |

`superpowers` is the heaviest and the most opinionated — it injects a "always invoke a
skill before responding" rule into every session. Flag that to the user before installing it.

Slack / CodeRabbit / Context7 each prompt for their own auth on first use.

`claude/settings.json` already lists these in `enabledPlugins` + `extraKnownMarketplaces` —
**strip the entries for plugins the user did not pick** before writing settings, or Claude
Code will complain about plugins that aren't installed.

## 3. CLI-provided skills (1) — NOT in this repo

| Skill | Comes from | Install |
|---|---|---|
| `agent-browser` | the agent-browser CLI, which installs its own skill at `~/.agents/skills/agent-browser` and symlinks it into `~/.claude/skills/` | Install the CLI per `external-deps.md`. Do not hand-copy the skill. |

`claude/CLAUDE.md` sets agent-browser as the default web-browsing tool — if the user skips
the CLI, either install it or edit that section out of CLAUDE.md.

---

## Jev decision layer (added 2026-09-21 → 09-23)

Small, fast judgement calls are delegated to [Jev](https://typesafe.ai) (TypeSafe "System One", hosted, ~100–400 ms, $0.04/M tokens) instead of an LLM turn. Every piece is **advisory and fails open** — no key, timeout or outage means the pre-Jev behaviour. Nothing here changes how Claude Code is used; it works underneath the same commands.

| Piece | Where | What it does |
|---|---|---|
| `bin/jev-ask` | CLI | one-shot typed questions (noul / choice / score) with masking, deadline, circuit breaker, `JEV_OFF=1` |
| Bash risk gate | `claude/scripts/jev-bash-risk-gate.sh` (PreToolUse Bash) | denies confident exfiltration / security downgrade / shared-branch rewrites, asks on sudo, curl-pipe-shell, risky deletes; read-only commands never leave the machine |
| PR risk pre-filter | `claude/scripts/jev-pr-risk.sh` inside the PR babysitter | billing / schema / auth / deploy-config PRs are announced but auto-merge is not armed |
| `jev-verify-report` | `claude/scripts/` | accept / verify / reject a subagent report before spending a skeptic pass (used by the `loopengg` skill) |
| Triage | `morning-triage`, `monday-triage` skills + `headless-triage-run.sh` + launchd | Slack/SMS and Monday-board hygiene digests, drafts only, never sends |
| `bin/jab`, `bin/jev-step` | CLI | agent-browser + Jev: one snapshot + one decision per click/fill/check; whole flows via [hunch](https://github.com/HAR5HA-7663/hunch) |
| `jev-compact` plugin | separate repo, listed above | `/compact` prunes exploration output, long tool inputs and hook noise by rule, Jev ranks the rest to a 45 % budget, built-in summary only as fallback |
| Brain rerank / ingest checks / staleness | `~/brain/scripts` (not in this repo) | see the brain section of `claude/CLAUDE.md` |

Key: `TYPESAFE_API_KEY` in `~/.env` under `[personal]` (see below). Logs: `~/.local/state/jev/*.log` (timings only, never content).

## Universal `~/.env` + `with-env`

All API keys live in one file, `~/.env` (mode 600), grouped in owner blocks (`[personal]`, `[bevri]`, `[teli]`, …). It is **never sourced by the shell**; `bin/with-env --scope <owner> --only NAME <cmd>` hands a key to one command on demand, so child processes never see the rest. `bin/env-sync` mirrors every project `.env` into it. Rules for the agent are in `claude/CLAUDE.md` → "Universal Env File". The file itself is obviously not in this repo — the installer must create it with at least:

```
[personal]
TYPESAFE_API_KEY=...
```

## Refreshing this repo from the machine

```
python3 export.py          # copy + scrub + regenerate manifest.json and mcp/mcp-servers.json
python3 export.py --check  # secret scan only
git add -A && git commit && git push
```

`export.py` refuses to leave anything that looks like a live credential in the tree. The push is also covered by the local malware guard, which blocks any file carrying an intact IOC literal unless that file is byte-identical to the live defender script in `~/.claude/scripts/` (our own scanners necessarily contain the strings they look for).

## UI features replicated

- **Statusline**: custom `statusline-custom.sh` (bash, needs `jq`)
- **TUI**: fullscreen mode, dark theme
- **Voice**: enabled, hold-to-talk
- **Permission mode**: `auto` (with dangerous-mode prompt skips)
- **Model/effort**: `claude-fable-5[1m]` at `xhigh` effort

## Not in this repo (by design)

- **`~/brain/`** — the personal LLM wiki (private data; since 2026-09-23 it has its own private repo). Copy it manually; see `external-deps.md`. The 6 brain/wiki skills are inert without it.
- **`~/.env`** — every API key. `with-env`, the Jev hooks and the jev-compact plugin read it; create it by hand.
- **Credentials** — Claude / GitHub / Slack / Monday / TypeSafe logins. The installer asks for these.
- **Malware IOC data** (`malware-ioc-canonical.txt` and friends) — derived from a private incident; `sync-malware-iocs.py` regenerates the guards from a local copy.
- **Claude auto-memory** (`~/.claude/projects/*/memory/`) — per-machine, path-specific.
- **hunch** and **jev-compact** source — their own public repos (linked above).
- **openmessage daemon** (backs the `gmessages` MCP server) — separate personal project.

Secrets were scrubbed before export (`export.py --check` re-verifies); anything needed at install time is a `<PLACEHOLDER>` the installing agent must ask the user for.
