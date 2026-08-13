# My_Claude_Setup

Full export of Harsha's Claude Code environment (exported 2026-08-02, skills refreshed 2026-08-13, from macOS on `claude-fable-5[1m]`). This repo lets a Claude Code agent on **any machine (macOS / Linux / Windows)** replicate the setup so it looks and functions the same.

> ## ⚠️ READ THIS FIRST — installing agent
>
> **Do NOT copy the whole `claude/skills/` folder. Do NOT install all 8 plugins.**
>
> Before installing anything you MUST show the user the skill catalog below and ask
> **which skills they actually need** — both the personal skills in this repo and the
> skills that arrive with each plugin. Install **only** what they pick.
>
> Nobody needs 44 personal skills + 30 plugin skills. Most of them are dead weight for a
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
| `claude/CLAUDE.md` | Global instructions: personal brain rules, subagent model tiering, agent-browser default, writing style |
| `claude/skills/` | **44 personal skills** — see the catalog below. Sub-selectable; do not bulk-copy. |
| `claude/agents/` | `poller` (haiku-pinned) and `scripted-runner` (sonnet-pinned) custom agents |
| `claude/commands/` | `/clipboard`, `/council` slash commands |
| `claude/scripts/` | Hook scripts: malware guards (git push / npm install / git pull) + PR babysitter |
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
| **2. Plugin-provided** (30) | Not in this repo — ships inside a plugin | `/plugin install <plugin>@<marketplace>` |
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

**Personal to Harsha (2)** — *contain his own résumé/application data. Do not install for anyone else.*
`job-applicator` · `job-ranker`

## 2. Plugin-provided skills (30) — NOT in this repo

These do **not** exist in `claude/skills/`. They arrive when the plugin is installed, and
they disappear when it's uninstalled. Ask the user per plugin — "do you want these skills?"
— and install only those plugins.

| Plugin | Install | Skills it brings | Slash commands |
|---|---|---|---|
| **superpowers** | `/plugin install superpowers@claude-plugins-official` | 14 — `brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development`, `dispatching-parallel-agents`, `systematic-debugging`, `test-driven-development`, `requesting-code-review`, `receiving-code-review`, `verification-before-completion`, `finishing-a-development-branch`, `using-git-worktrees`, `writing-skills`, `using-superpowers` | — |
| **slack** | `/plugin install slack@claude-plugins-official` | 7 — `slack-api`, `slack-cli`, `slack-docs`, `slack-search`, `slack-messaging`, `block-kit`, `create-slack-app` | `/channel-digest`, `/draft-announcement`, `/find-discussions`, `/standup`, `/summarize-channel` |
| **caveman** | `claude plugin marketplace add JuliusBrussee/caveman` then `/plugin install caveman@caveman` | 4 — `caveman` (compressed comms mode), `caveman-commit`, `caveman-review`, `compress` | — |
| **coderabbit** | `/plugin install coderabbit@claude-plugins-official` | 2 — `code-review`, `autofix` | `/coderabbit-review` |
| **imessage** *(macOS only)* | `/plugin install imessage@claude-plugins-official` | 2 — `access`, `configure` | — |
| **claude-md-management** | `/plugin install claude-md-management@claude-plugins-official` | 1 — `claude-md-improver` | `/revise-claude-md` |
| **context7** | `/plugin install context7@claude-plugins-official` | 0 — provides an MCP server for live library docs, no skills | — |
| **swift-lsp** *(macOS only)* | `/plugin install swift-lsp@claude-plugins-official` | 0 — provides Swift LSP integration, no skills | — |

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

## UI features replicated

- **Statusline**: custom `statusline-custom.sh` (bash, needs `jq`)
- **TUI**: fullscreen mode, dark theme
- **Voice**: enabled, hold-to-talk
- **Permission mode**: `auto` (with dangerous-mode prompt skips)
- **Model/effort**: `claude-fable-5[1m]` at `xhigh` effort

## Not in this repo (by design)

- **`~/brain/`** — the personal LLM wiki (private data). Copy it manually; see `external-deps.md`. The 6 brain/wiki skills are inert without it.
- **Credentials** — Claude/GitHub/Slack/Monday logins, CompAI API key. The installer asks for these.
- **gmessages daemon** — separate personal project.

Secrets were scrubbed before export; anything needed at install time is a `<PLACEHOLDER>` the installing agent must ask the user for.
