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
  - Personal skills (28) — *sub-selected in Phase 1b, never bulk-installed*
  - Agents + slash commands
- **Question 2 — Tooling** (default ON):
  - Hook + automation scripts (malware guards, PR babysitter, Jev risk gate, triage runners, mem-guard)
  - CLI tools (`bin/`: with-env, env-sync, jev-ask, jev-step, jab, jev-replicate) + shell launcher (`shell/`)
  - Custom statusline
  - Plugins (7 enabled, bringing 73 more skills) — *sub-selected in Phase 1b*
- **Question 3 — Integrations** (default OFF, each has prereqs/secrets):
  - MCP servers (then sub-select which of the 4)
  - External CLI tools (agent-browser, hunch, uv, carbontype, mcp_excalidraw) + the TypeSafe key in `~/.env`
  - launchd jobs (macOS schedules — brain watcher/sync, daily brain sync, malware sweep, mem-guard, triage; run them on ONE machine only)
  - Brain system pointer (~/brain — manual copy by user)

If `AskUserQuestion` is unavailable in your harness, print a numbered checklist and have
the user reply with the numbers to install. **Never install anything not selected.**

## Phase 1b — Ask WHICH SKILLS (REQUIRED, never skip, never bulk-install)

Selecting "skills" in Phase 1 does **not** mean copy all 28. Selecting "plugins" does
**not** mean install all 8. Skills are the most context-expensive thing in this repo —
every installed skill's name + description is loaded into every session — so an
unwanted skill is a permanent tax, not a harmless extra.

Read the skill catalog from `manifest.json` (`components[id=skills].items` for the
personal ones, `components[id=plugins].catalog` for the plugin-provided ones; the README
has the same lists grouped for humans). Then:

1. **Present the personal skills grouped by theme** (brain/wiki, orchestration, design,
   GSAP, documents, testing, personal-to-Harsha) with a one-line description each, and ask
   which groups or individual skills the user wants. Multi-select, nothing pre-checked
   except what they clearly need.
2. **Present the plugins by what skills each one brings** — the user is choosing skills,
   not plugin names. E.g. "superpowers brings 14 process skills (brainstorming, TDD,
   systematic-debugging, code-review flow…) and injects an always-invoke-a-skill rule into
   every session — want it?" Install only the plugins whose skills they said yes to.
3. **Call out the ones with hard dependencies before they pick:**
   - `brain-query`, `brain-status`, `wiki-*` (6) are dead weight without `~/brain`, which
     is NOT in this repo. If the user isn't restoring the brain, recommend skipping all 6.
   - `job-applicator`, `job-ranker` contain Harsha's personal résumé/application data.
     Only install if the new machine is his.
   - The 8 `gsap-*` skills only matter to someone writing GSAP animations — all-or-nothing.
   - `agent-browser` is not in this repo at all (see the `skills` section below).
   - `imessage` and `swift-lsp` plugins are macOS-only — auto-deselect elsewhere and say so.
4. **Record the selection** and use it in Phase 2 for both the file copy and the
   `settings.local.json` / `enabledPlugins` cleanup.

Never copy `claude/skills/` wholesale "to save a round trip." Asking is the point.

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
Copy **only the skill folders the user picked in Phase 1b** from `claude/skills/` →
`~/.claude/skills/`. All are plain-markdown skill dirs; no build step, no dependencies
between them — each folder stands alone.

- Skipping the brain? Then do not copy `brain-query`, `brain-status`, `wiki-ingest`,
  `wiki-lint`, `wiki-query`, `wiki-save` — they will error on every invocation.
- `job-applicator` / `job-ranker` hold Harsha's personal application data — confirm the
  new machine is his before copying.
- `agent-browser` is **not in this repo**. The agent-browser CLI installs its own skill at
  `~/.agents/skills/agent-browser` and symlinks it into `~/.claude/skills/`. If the user
  wants it, install the CLI (external-tools) — never hand-create that symlink.
- After copying, prune `~/.claude/settings.local.json` so it only references skills that
  actually landed.

Report back exactly which skills were installed and which were skipped.

### agents
Copy `claude/agents/*.md` → `~/.claude/agents/`. These pin models (haiku/sonnet) — no other setup.

### commands
Copy `claude/commands/*.md` → `~/.claude/commands/`.

### hook-scripts
1. Copy `claude/scripts/*` → `~/.claude/scripts/` and `chmod +x` them (macOS/Linux).
2. They require `bash`, `git`, `python3`, `jq`, and (PR babysitter) `gh` authenticated. On Windows confirm hooks execute via Git Bash — run one manually as a smoke test.
3. These are wired by the hooks block installed in core-settings (PreToolUse: git-push guard → local malware precheck → Jev risk gate; PostToolUse: malware postcheck, PR babysitter; SessionStart: brain context, TCC cleaner).
4. The `jev-*` scripts need `bin/jev-ask` on PATH and `TYPESAFE_API_KEY` in `~/.env`; without them they fail open (no gate, no pre-filter) and say so in their logs under `~/.local/state/jev/`.
5. The malware IOC list is NOT in the repo. `sync-malware-iocs.py` expects `~/.claude/scripts/malware-ioc-canonical.txt` (one literal per line) — ask the user for it or the guards keep their built-in split patterns.

### cli-tools
1. Copy `bin/*` → `~/.local/bin/` (`chmod +x`, make sure it is on PATH). They are plain `sh`/`python3` scripts.
2. Create `~/.env` (mode 600) with at least `[personal]` + `TYPESAFE_API_KEY=` (ask the user; never invent it). `with-env --blocks` must list the block; `with-env` refuses to run if the file is not mode 600/400.
3. `jev-step` and `jab` additionally need agent-browser and hunch (see external-deps.md).
4. Smoke test: `printf 'git push --force origin main' | jev-ask --purpose test --noul risky "Would this rewrite shared git history?"` prints a probability.

### launchd-jobs (macOS only, default OFF)
1. Rewrite every `/Users/HAR5HA` in `launchd/*.plist` to the new home, copy to `~/Library/LaunchAgents/`, `launchctl load` each.
2. `com.harsha.brain-watch` / `brain-sync` / `daily-brain-sync` need `~/brain`; `malware-sweep` and `mem-guard` need the scripts from hook-scripts; the triage jobs need the triage skills, Slack plugin / Monday MCP and the key.
3. Only ONE machine should run daily-brain-sync and the triage jobs, or digests duplicate. Linux: systemd user units; Windows: Task Scheduler.

### shell
Append `shell/zshrc-claude.zsh` to `~/.zshrc` (or the equivalent). It makes `claude` start with `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1` (required by the jev-compact plugin, harmless otherwise) and adds `claude-plain`. Requires Claude Code ≥ 2.1.274.

### statusline
1. Copy `claude/statusline-custom.sh`, `claude/statusline.sh`, and `claude/statusline/` → `~/.claude/`, `chmod +x` the scripts.
2. Requires `jq` (`brew install jq` / `apt install jq` / available in Git Bash via winget or scoop).
3. Verify: `echo '{}' | bash ~/.claude/statusline-custom.sh` should print a statusline, not errors.

### plugins
Install **only the plugins whose skills the user asked for in Phase 1b.** Each plugin
brings its own skills into every session; installing one the user doesn't want is the same
mistake as copying a skill they didn't want. Full per-plugin skill lists are in
`manifest.json` → `components[id=plugins].catalog`, and in the README table.

Run in a Claude Code session (or via `claude` CLI where supported):

| Plugin | Command | Brings |
|---|---|---|
| superpowers | `/plugin install superpowers@claude-plugins-official` | 14 process skills **+ an always-invoke-a-skill rule in every session** — say this out loud before installing |
| vercel | `/plugin install vercel@claude-plugins-official` | 35 skills, 3 agents, 5 commands, Vercel MCP (OAuth on first use) |
| stripe | `/plugin install stripe@claude-plugins-official` | 9 skills, 2 commands, Stripe MCP (OAuth on first use) |
| slack | `/plugin install slack@claude-plugins-official` | 8 skills + 5 slash commands + Slack MCP (OAuth on first use) |
| caveman | `claude plugin marketplace add JuliusBrussee/caveman` then `/plugin install caveman@caveman` | 4 skills (compressed-output modes) |
| codex | `claude plugin marketplace add openai/codex-plugin-cc` then `/plugin install codex@openai-codex` | 3 skills, 8 commands, `codex-rescue` agent (needs the Codex CLI) |
| jev-compact | `git clone https://github.com/HAR5HA-7663/jev-compact ~/Desktop/Personal/jev-compact && claude plugin marketplace add ~/Desktop/Personal/jev-compact && claude plugin install jev-compact@jev-compact --config targetPercent=45 --config compactAtPercent=75 --config preserveRecentMessages=12 --config minReductionRatio=0.25 --config model=jev-1.13.0 --config brainArchive=true` | prune-not-summarise `/compact`; needs the `shell/` launcher + `TYPESAFE_API_KEY` in `~/.env` (falls back to the built-in summary without it) |
| coderabbit / imessage / swift-lsp | `/plugin install <name>@claude-plugins-official` | installed but **disabled** on the source machine — skip unless the user asks |

Then **strip `enabledPlugins` and `extraKnownMarketplaces` entries in the installed
`settings.json` for every plugin the user declined** — leaving them in makes Claude Code
complain about plugins that were never installed.

Slack / Vercel / Stripe / CodeRabbit prompt for their own auth on first use — let them.

### mcp-servers
For each server the user sub-selected, read its `_prereq` in `mcp/mcp-servers.json`,
satisfy it, replace `<PLACEHOLDERS>` (`<HOME>` and any `<…_KEY>` — ask the user for
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
3. The skill list shows **exactly** the skills the user selected — no more. If skills the
   user declined are showing up, find where they came from (a plugin they didn't ask for,
   or a bulk copy) and remove them. `/council` and `/clipboard` resolve.
4. If hooks installed: `git push` in a scratch repo triggers the malware-guard status message.
5. If MCP servers installed: `/mcp` shows them connected (monday will ask for OAuth — expected).
6. If brain restored: new session auto-loads the brain context via the SessionStart hook.
7. If cli-tools installed: `with-env --blocks` lists `[personal]`; the `jev-ask` smoke test above prints a probability; `~/.local/state/jev/bash-gate.log` gets a line after any non-read-only Bash command.
8. If jev-compact installed: `/compact` in a session with a few tool calls writes a line to `~/.local/state/jev/compact.log` (`pruned` or `hybrid`).

Report a final summary: what was installed, what was skipped and why, and any manual
follow-ups left for the user (auth logins, brain copy, API keys).
