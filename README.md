# My_Claude_Setup

Full export of Harsha's Claude Code environment (exported 2026-08-02 from macOS, Claude Code on `claude-fable-5[1m]`). This repo lets a Claude Code agent on **any machine (macOS / Linux / Windows)** replicate the setup so it looks and functions the same.

> **⚠️ For the installing agent: read [`INSTALL_AGENT.md`](INSTALL_AGENT.md) and follow it exactly.**
> Do NOT blindly copy files. You must first present the component checklist to the user
> (multi-select), and install **only** what they pick, adapting paths per OS.

## Quick start on the new machine

1. Install prerequisites: `git`, `gh` (GitHub CLI), Node.js ≥ 18, and Claude Code itself
   (`npm install -g @anthropic-ai/claude-code` or the native installer).
2. `gh auth login` and clone this repo.
3. Open Claude Code in the cloned repo and tell the agent:

   > Read INSTALL_AGENT.md in this repo and install my Claude setup. Ask me which
   > components I want first, then install exactly those.

## What's in here

| Path | Contents |
|---|---|
| `manifest.json` | Machine-readable catalog of every component (the installer's source of truth) |
| `INSTALL_AGENT.md` | Step-by-step instructions for the installing agent, incl. the selection UX |
| `claude/settings.json` | Model (`claude-fable-5[1m]`), effort `xhigh`, fullscreen TUI, dark theme, voice (hold mode), auto permission mode, hooks, statusline wiring, enabled plugins, env vars |
| `claude/settings.local.json` | Skill visibility overrides |
| `claude/CLAUDE.md` | Global instructions: personal brain rules, subagent model tiering, agent-browser default, writing style |
| `claude/skills/` | 34 user skills (brain/wiki suite, council, design suite, docx/pptx/xlsx/pdf, agent-browser, job-applicator, …) |
| `claude/agents/` | `poller` (haiku-pinned) and `scripted-runner` (sonnet-pinned) custom agents |
| `claude/commands/` | `/clipboard`, `/council` slash commands |
| `claude/scripts/` | Hook scripts: malware guards (git push / npm install / git pull) + PR babysitter |
| `claude/statusline-custom.sh` + `claude/statusline/` | Custom statusline (active) + claude-code-statusline package v2.24.0 |
| `mcp/mcp-servers.json` | User-scope MCP servers (secrets replaced with `<PLACEHOLDERS>`) |
| `extras/harsha-slack-writing-style.md` | Writing-style guide referenced by CLAUDE.md |
| `external-deps.md` | Things NOT in this repo that the setup depends on (brain, agent-browser, daemons) |

## UI features replicated

- **Statusline**: custom `statusline-custom.sh` (bash, needs `jq`)
- **TUI**: fullscreen mode, dark theme
- **Voice**: enabled, hold-to-talk
- **Permission mode**: `auto` (with dangerous-mode prompt skips)
- **Model/effort**: `claude-fable-5[1m]` at `xhigh` effort

## Plugins (8)

`superpowers`, `context7`, `slack`, `swift-lsp`, `coderabbit`, `claude-md-management`, `imessage` (all `@claude-plugins-official`) + `caveman` (marketplace `JuliusBrussee/caveman`).

## Not in this repo (by design)

- **`~/brain/`** — the personal LLM wiki (private data). Copy it manually; see `external-deps.md`.
- **Credentials** — Claude/GitHub/Slack/Monday logins, CompAI API key. The installer asks for these.
- **gmessages daemon** — separate personal project.

Secrets were scrubbed before export; anything needed at install time is a `<PLACEHOLDER>` the installing agent must ask the user for.
