# INSTALL_AGENT.md — Instructions for the Installing Agent

You are a Claude Code agent on a NEW machine. Your job: replicate Harsha's Claude Code
setup from this repo so it looks and functions the same as the source machine. Follow
these phases **in order**. `manifest.json` is your source of truth for what exists.

---

## Phase 0 — Detect the environment

1. Detect OS (macOS / Linux / Windows) and the user's home directory.
2. Verify Claude Code is installed (`claude --version`). If not, stop and help the user install it first.
3. Check for `git`, `gh`, `node`/`npx`, `jq`, and (Windows only) Git Bash. Record what's missing — you'll install prerequisites only for components the user actually selects.
4. Check whether `~/.claude/` already has content. If existing `settings.json`, `CLAUDE.md`, skills, or agents are present, you MUST NOT overwrite them without telling the user what would be replaced and getting confirmation. Offer to back up (`~/.claude-backup-<date>/`) before writing anything.

## Phase 1 — Ask the user what to install (REQUIRED, never skip)

Present the components from `manifest.json` as a **multi-select checklist** and install
only what's confirmed. Use the `AskUserQuestion` tool with `multiSelect: true`. It allows
max 4 options per question, so split across questions like this (or equivalent):

- **Question 1 — Core** (all default ON):
  - Core settings (model, hooks wiring, statusline ref, permissions, env)
  - Global CLAUDE.md + writing style guide
  - Skills (34)
  - Agents + slash commands
- **Question 2 — Tooling** (default ON):
  - Hook scripts (malware guards + PR babysitter)
  - Custom statusline
  - Plugins (8)
- **Question 3 — Integrations** (default OFF, each has prereqs/secrets):
  - MCP servers (then sub-select which of the 5)
  - External CLI tools (agent-browser, carbontype, mcp_excalidraw)
  - Brain system pointer (~/brain — manual copy by user)

If `AskUserQuestion` is unavailable in your harness, print a numbered checklist and have
the user reply with the numbers to install. **Never install anything not selected.**

After selection, resolve dependencies and tell the user about consequences, e.g.:
- Core settings hooks reference `claude/scripts/*` → if hook-scripts NOT selected, strip those hook entries from the settings you install.
- Core settings `statusLine` references `statusline-custom.sh` → if statusline NOT selected, remove the `statusLine` block.
- SessionStart hook + `brain-fs` MCP + brain/wiki skills depend on `~/brain` existing → if the user isn't restoring the brain, remove the SessionStart hook entry, skip `brain-fs`, and warn that `brain-query`/`brain-status`/`wiki-*` skills will be dead weight (offer to skip copying them).
- `imessage` and `swift-lsp` plugins and the `computer-use`-style macOS integrations only make sense on macOS — auto-deselect on Linux/Windows and say so.

## Phase 2 — Install per component

Work through the selected components in this order. All targets are under the user's
home (`~` = `$HOME`, on Windows `%USERPROFILE%`; `~/.claude` is the same folder name on
all three OSes).

### core-settings
1. Read `claude/settings.json` from this repo. Rewrite before writing:
   - Every `/Users/HAR5HA` → the new home directory.
   - `AGENT_BROWSER_EXECUTABLE_PATH`: macOS `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`; Linux `/usr/bin/google-chrome` (verify); Windows `C:\Program Files\Google\Chrome\Application\chrome.exe` (verify). If Chrome isn't installed, drop the env var (agent-browser falls back to its bundled Chrome).
   - Strip hook/statusline/plugin entries for unselected components (see Phase 1).
   - Keep: `model`, `effortLevel: xhigh`, `tui: fullscreen`, `theme: dark`, `voice`, permission mode + `permissions` block (the `deny` list for gmessages send tools matters), `enabledPlugins`, `extraKnownMarketplaces`.
   - If the user's account doesn't have access to `claude-fable-5[1m]`, ask which model to use instead — don't silently keep an invalid model.
2. Write to `~/.claude/settings.json`.
3. Write `claude/settings.local.json` → `~/.claude/settings.local.json` (skill overrides only; drop overrides for skills that weren't copied).

### global-claude-md
1. Copy `claude/CLAUDE.md` → `~/.claude/CLAUDE.md`.
2. Copy `extras/harsha-slack-writing-style.md` somewhere stable (ask user; default `~/Documents/`), then update the path reference inside CLAUDE.md.
3. If the brain is not being restored, tell the user the "Personal Brain" section will be inert until `~/brain` exists (it's safe to leave in place).

### skills
Copy selected skill folders from `claude/skills/` → `~/.claude/skills/`. All are
plain-markdown skill dirs; no build step. Platform notes: `agent-browser` skill needs the
agent-browser CLI (external-tools component); `job-applicator` contains Harsha's personal
application data — confirm the new machine is his before copying.

### agents
Copy `claude/agents/*.md` → `~/.claude/agents/`. These pin models (haiku/sonnet) — no other setup.

### commands
Copy `claude/commands/*.md` → `~/.claude/commands/`.

### hook-scripts
1. Copy `claude/scripts/*.sh` → `~/.claude/scripts/` and `chmod +x` them (macOS/Linux).
2. They require `bash`, `git`, and (PR babysitter) `gh` authenticated. On Windows confirm hooks execute via Git Bash — run one manually as a smoke test.
3. These are wired by the hooks block installed in core-settings.

### statusline
1. Copy `claude/statusline-custom.sh`, `claude/statusline.sh`, and `claude/statusline/` → `~/.claude/`, `chmod +x` the scripts.
2. Requires `jq` (`brew install jq` / `apt install jq` / available in Git Bash via winget or scoop).
3. Verify: `echo '{}' | bash ~/.claude/statusline-custom.sh` should print a statusline, not errors.

### plugins
Run in a Claude Code session (or via `claude` CLI where supported):
1. `claude plugin marketplace add JuliusBrussee/caveman`
2. `/plugin install caveman@caveman`
3. `/plugin install superpowers@claude-plugins-official`
4. `/plugin install context7@claude-plugins-official`
5. `/plugin install slack@claude-plugins-official`
6. `/plugin install coderabbit@claude-plugins-official`
7. `/plugin install claude-md-management@claude-plugins-official`
8. macOS only: `/plugin install swift-lsp@claude-plugins-official` and `/plugin install imessage@claude-plugins-official`
Slack/CodeRabbit/Context7 will prompt their own auth on first use — let them.

### mcp-servers
For each server the user sub-selected, read its `_prereq` in `mcp/mcp-servers.json`,
satisfy it, replace `<PLACEHOLDERS>` (`<HOME>`, `<COMPAI_API_KEY>` — ask the user for
secrets, never invent them), then register with `claude mcp add --scope user` (or merge
into `~/.claude.json` `mcpServers`). Skip any server whose prereq can't be met and tell
the user why.

### external-tools
See `external-deps.md` for install commands per OS.

### brain-system
You cannot install this — the data is private and not in this repo. Tell the user to copy
`~/brain` from the old machine (rsync/AirDrop/drive), then on the new machine set up its
Python venv and watcher per `~/brain/scripts/` and re-run embedding if paths changed.
macOS launchd agent `com.harsha.brain-watch` has no direct equivalent on Linux/Windows —
offer systemd user unit / Task Scheduler as replacements if asked.

## Phase 3 — Verify

Run through this checklist and report results honestly (don't claim success without checking):
1. `claude --version` starts; new session shows dark fullscreen TUI and the custom statusline.
2. `/plugins` lists the selected plugins; `/hooks` (or settings inspection) shows the installed hooks.
3. Skills appear in the skill list; `/council` and `/clipboard` resolve.
4. If hooks installed: `git push` in a scratch repo triggers the malware-guard status message.
5. If MCP servers installed: `/mcp` shows them connected (monday will ask for OAuth — expected).
6. If brain restored: new session auto-loads the brain context via the SessionStart hook.

Report a final summary: what was installed, what was skipped and why, and any manual
follow-ups left for the user (auth logins, brain copy, API keys).
