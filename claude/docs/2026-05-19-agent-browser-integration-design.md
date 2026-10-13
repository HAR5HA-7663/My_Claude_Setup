# agent-browser Integration — Design

**Date:** 2026-05-19
**Status:** Approved
**Goal:** Make `agent-browser` the default web-browsing tool for Claude Code, keep `claude-in-chrome` MCP as a fallback.

## Background

`agent-browser` (Vercel Labs, v0.27.0) is a native Rust CLI that drives Chrome via the Chrome DevTools Protocol through a persistent background daemon. It bundles Chrome for Testing. It is **not** an MCP server — it is command-line only, so Claude Code drives it through the Bash tool.

## Decisions

| Decision | Choice |
|---|---|
| Drive method | Official Vercel skill (`npx skills add vercel-labs/agent-browser`) |
| claude-in-chrome | Keep as fallback (agent-browser is default) |
| Browser backend | Local — bundled Chrome for Testing, no API keys |
| CLI install | npm global (`npm install -g agent-browser`) |

## Components

1. **CLI install** — `npm install -g agent-browser`. Installs the Rust binary plus bundled Chrome for Testing. Daemon auto-starts on first command and persists between calls.

2. **Official skill** — `npx skills add vercel-labs/agent-browser` drops the Vercel-maintained skill into `~/.claude/skills/`. Teaches Claude the command set: `open`, `snapshot -i`, `click @eN`, `--json` output, `chat`.

3. **CLAUDE.md routing rule** — a new section in `~/.claude/CLAUDE.md`:
   - Default web browsing → `agent-browser` CLI via Bash.
   - Fallback → `claude-in-chrome` MCP, only when GIF recording or network/console inspection is needed.
   - This intentionally overrides the built-in MCP instruction that says to use claude-in-chrome for web tasks.

4. **Bash permission** — add `agent-browser` to the allow list in `~/.claude/settings.json` so calls are not prompted every time.

## Data Flow

```
Claude needs web -> agent-browser skill -> Bash: `agent-browser open|snapshot|click`
  -> Rust daemon (persistent) -> CDP -> bundled Chrome
  -> snapshot text with @e1,@e2 element refs -> back to Claude
```

## Out of Scope / Untouched

- `claude-in-chrome` MCP config — unchanged.
- `job-applicator`, brain/wiki skills — unchanged; they inherit the faster default browser.
- No cloud browser provider (Browserbase/Browserless) — local only for now.

## Verification

```
agent-browser open example.com
agent-browser snapshot -i
```

Pass = snapshot returns page content with `@eN` element references.

## Risks

- The Vercel skill text may conflict with the built-in claude-in-chrome MCP instruction. Mitigated by the explicit CLAUDE.md routing rule (highest priority).
- First run downloads Chrome for Testing (~150 MB) — one-time.
