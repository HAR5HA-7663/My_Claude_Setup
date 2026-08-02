# External Dependencies (not in this repo)

Things the setup references that must be installed/copied separately.

## agent-browser (default web-browsing tool)

Vercel Labs browser-automation CLI, v0.27.0 on the source machine (installed via Homebrew).

- macOS: `brew install agent-browser` (or `npm install -g agent-browser`)
- Linux/Windows: `npm install -g agent-browser`
- Config comes from `settings.json` env vars: headed mode, real Chrome executable, dedicated
  automation profile dir at `~/.agent-browser/chrome-automation` (created on first run).
- Login state in that profile does NOT transfer unless the user copies
  `~/.agent-browser/chrome-automation` from the old machine.

## carbontype

Harsha's own CLI that types a text file into a focused window like a human.

- `git clone https://github.com/HAR5HA-7663/carbontype ~/tools/carbontype` and follow its README.
- Referenced by memory/workflows, not by settings.json — optional.

## mcp_excalidraw (backs the `excalidraw` MCP server)

- `git clone https://github.com/yctimlin/mcp_excalidraw.git ~/tools/mcp_excalidraw`
- `cd ~/tools/mcp_excalidraw && npm install && npm run build`
- The MCP entry points at `~/tools/mcp_excalidraw/dist/index.js` (see `mcp/mcp-servers.json`).

## ~/brain — personal LLM wiki ("Graphify")

Private data, deliberately excluded. The user must copy the whole `~/brain` directory from
the old machine themselves. It contains: `raw/`, `wiki/`, `scripts/` (Python embed/watch/query),
`.chroma/` vector store, `.venv/`. After copying:

1. Recreate the venv if the OS/arch changed: `python3 -m venv ~/brain/.venv && ~/brain/.venv/bin/pip install -r` (see brain's own docs/requirements).
2. Check `~/brain/.env` (privacy flag `BRAIN_PRIVACY_STRICT`, embedding provider keys).
3. Watcher daemon: macOS uses launchd (`~/Library/LaunchAgents/com.harsha.brain-watch.plist`,
   also not in this repo — copy from old machine). Linux: create a systemd user unit running
   `scripts/watch.py`. Windows: Task Scheduler.
4. The SessionStart hook in settings.json runs `~/brain/scripts/session_context.sh` — it will
   fail harmlessly until the brain exists.

## gmessages daemon

Local Google Messages MCP daemon on `127.0.0.1:7007` — separate personal project, not in
this repo. Skip the `gmessages` MCP server unless it's running on the new machine. Keep the
`mcp__gmessages__send_*` deny rules from settings.json if installed (read-only policy).

## GitHub CLI

`gh` must be installed and authenticated (`gh auth login`) for the PR-babysitter hook and
normal workflow. Scopes on the source machine: gist, read:audit_log, read:org, repo, workflow.

## Google Chrome

Real Chrome is used by agent-browser (headed). Install per OS and fix
`AGENT_BROWSER_EXECUTABLE_PATH` in settings.json accordingly.
