#!/usr/bin/env python3
"""export.py — refresh this repo from the live Claude Code setup on this machine.

    python3 export.py            # sync + regenerate manifest.json and mcp/mcp-servers.json
    python3 export.py --check    # only scan the repo for secrets / private strings, exit 1 on a hit

Idempotent. Copies ~/.claude config, skills, agents, commands, hook scripts, statusline,
the CLI tools in ~/.local/bin that the hooks depend on, the Claude-related launchd jobs and
the shell launcher. Never copies ~/.env, ~/.claude.json wholesale, ~/brain, logs, backups,
the malware IOC data files (kept local: they are derived from a private incident and would
trip the push guard) or anything under ~/.claude/skills/synced (host-managed).
"""
from __future__ import annotations

import datetime as dt
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
C = HOME / ".claude"
REPO = Path(__file__).resolve().parent
TODAY = dt.date.today().isoformat()

SKILL_EXCLUDES = ["synced", "agent-browser", "__pycache__", "*.pyc", ".DS_Store", "node_modules", "*.log", ".venv", "*.skill"]
SCRIPT_EXCLUDES = ["*.bak*", "*.pre-ioc-sync", "*.log", ".tcc-clean-last-version", "__pycache__", ".DS_Store",
                   "malware-ioc-canonical.txt", "malware-ioc-bundle-exclude.txt", "malware-guard-targets.txt"]
BIN_TOOLS = ["with-env", "env-sync", "jev-ask", "jev-step", "jab", "jev-replicate"]
LAUNCHD = ["com.harsha.brain-watch", "com.harsha.daily-brain-sync", "com.harsha.brain-sync", "com.harsha.malware-sweep",
           "com.harsha.mem-guard", "com.harsha.morning-triage", "com.harsha.monday-triage"]
MCP_PREREQ = {
    "brain-fs": "Requires ~/brain to exist (personal LLM wiki — private, NOT in this repo). `npm i -g @modelcontextprotocol/server-filesystem` or keep the npx form. Skip if the user is not restoring the brain.",
    "excalidraw": "Clone https://github.com/yctimlin/mcp_excalidraw.git into ~/tools/mcp_excalidraw, then `npm install && npm run build` so dist/index.js exists.",
    "monday": "OAuth on first use — run /mcp inside Claude Code and authenticate in the browser.",
    "gmessages": "Requires the openmessage daemon (Google Messages bridge, separate personal project) serving MCP on 127.0.0.1:7007. Skip unless the user runs it. Keep the settings.json permissions.deny entries for mcp__gmessages__send_* — read-only use.",
}
SAFE_ENV_KEYS = {"EXPRESS_SERVER_URL", "ENABLE_CANVAS_SYNC", "PORT", "PATH", "HOME"}
# anything that looks like a live credential anywhere in the export → abort
SECRET_PATTERNS = [
    re.compile(r"\bapikey_[0-9a-f]{20,}"), re.compile(r"\bsk-[A-Za-z0-9_\-]{20,}"), re.compile(r"\b(sk|rk|pk)_(live|test)_[A-Za-z0-9]{16,}"),
    re.compile(r"\b(ghp|gho|ghs|github_pat)_[A-Za-z0-9_]{20,}"), re.compile(r"\bxox[abp]-[A-Za-z0-9\-]{10,}"), re.compile(r"\bcomp_[A-Za-z0-9]{16,}"),
    re.compile(r"(?i)\b(api[_-]?key|secret|token|password)\s*[=:]\s*['\"]?[A-Za-z0-9_\-]{24,}"),
    re.compile(r"\bey[A-Za-z0-9_\-]{30,}\.[A-Za-z0-9_\-]{20,}\."),   # JWT
]
SECRET_ALLOW = re.compile(r"(re\.compile|<[A-Z_]+>|PLACEHOLDER|example|\\b\(|regex|pattern|mask)")


def say(msg: str) -> None:
    print(f"  {msg}")


def rsync(src: Path, dst: Path, excludes: list[str], delete: bool = True) -> None:
    dst.mkdir(parents=True, exist_ok=True)
    cmd = ["rsync", "-a", "--no-links", "--no-perms", "--no-owner", "--no-group"] + (["--delete"] if delete else [])
    for e in excludes:
        cmd += ["--exclude", e]
    cmd += [f"{src}/", f"{dst}/"]
    subprocess.run(cmd, check=True)


def frontmatter(path: Path) -> dict[str, str]:
    try:
        text = path.read_text(errors="replace")
    except OSError:
        return {}
    if not text.startswith("---"):
        return {}
    body = text.split("---", 2)
    if len(body) < 3:
        return {}
    out: dict[str, str] = {}
    for line in body[1].splitlines():
        m = re.match(r"^([A-Za-z_-]+):\s*(.*)$", line)
        if m:
            out[m.group(1)] = m.group(2).strip().strip('"').strip("'")
    return out


def short(s: str, n: int = 170) -> str:
    s = " ".join(s.split())
    return s if len(s) <= n else s[: n - 1] + "…"


# ---------------------------------------------------------------- copy steps
def sync_claude_dir() -> None:
    say("claude/CLAUDE.md, settings.json, settings.local.json")
    shutil.copy2(C / "CLAUDE.md", REPO / "claude/CLAUDE.md")
    for name in ("settings.json", "settings.local.json"):
        src = C / name
        if src.exists():
            data = json.loads(src.read_text())
            (REPO / "claude" / name).write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    say("skills / agents / commands / scripts (rsync --delete)")
    rsync(C / "skills", REPO / "claude/skills", SKILL_EXCLUDES)
    rsync(C / "agents", REPO / "claude/agents", ["*.bak*", ".DS_Store"])
    rsync(C / "commands", REPO / "claude/commands", ["*.bak*", ".DS_Store"])
    rsync(C / "scripts", REPO / "claude/scripts", SCRIPT_EXCLUDES)
    say("statusline")
    for name in ("statusline-custom.sh", "statusline.sh"):
        if (C / name).exists():
            shutil.copy2(C / name, REPO / "claude" / name)
    if (C / "statusline").is_dir():
        rsync(C / "statusline", REPO / "claude/statusline", ["node_modules", ".DS_Store", "*.log"])


def sync_bin() -> None:
    say("bin/ (CLI tools the hooks and skills call)")
    d = REPO / "bin"
    d.mkdir(exist_ok=True)
    for t in BIN_TOOLS:
        src = HOME / ".local/bin" / t
        if src.exists():
            shutil.copy2(src, d / t)
            os.chmod(d / t, 0o755)
        else:
            say(f"  (missing on this machine: {t})")


def sync_launchd() -> None:
    say("launchd/ (scheduled jobs, macOS)")
    d = REPO / "launchd"
    d.mkdir(exist_ok=True)
    for name in LAUNCHD:
        src = HOME / "Library/LaunchAgents" / f"{name}.plist"
        if not src.exists():
            say(f"  (not installed here: {name})")
            continue
        with src.open("rb") as fh:
            data = plistlib.load(fh)
        env = data.get("EnvironmentVariables") or {}
        for k in list(env):
            if k not in SAFE_ENV_KEYS and re.search(r"(?i)key|token|secret|pass", k):
                env[k] = f"<{k}>"
        with (d / f"{name}.plist").open("wb") as fh:
            plistlib.dump(data, fh, sort_keys=True)


def sync_mcp() -> None:
    say("mcp/mcp-servers.json (scrubbed)")
    live = json.loads((HOME / ".claude.json").read_text()).get("mcpServers", {})
    out: dict[str, object] = {
        "_comment": "User-scope MCP servers (live in ~/.claude.json under mcpServers, or add via `claude mcp add --scope user`). "
                    "Placeholders in <ANGLE_BRACKETS> must be filled in by the installing agent after asking the user. "
                    "See INSTALL_AGENT.md for prerequisites per server.",
        "mcpServers": {},
    }
    home = str(HOME)
    for name, cfg in sorted(live.items()):
        entry: dict[str, object] = {}
        for k in ("type", "command", "url"):
            if k in cfg:
                entry[k] = str(cfg[k]).replace(home, "<HOME>")
        if "args" in cfg:
            entry["args"] = [str(a).replace(home, "<HOME>") for a in cfg["args"]]
        if "env" in cfg:
            entry["env"] = {k: (v if k in SAFE_ENV_KEYS or not re.search(r"(?i)key|token|secret|pass|auth", k) else f"<{k}>")
                            for k, v in cfg["env"].items()}
        if "headers" in cfg:
            entry["headers"] = {k: f"<{k.upper().replace('-', '_')}>" for k in cfg["headers"]}
        entry["_prereq"] = MCP_PREREQ.get(name, "Ask the user whether they use this server and what it needs before installing it.")
        out["mcpServers"][name] = entry  # type: ignore[index]
    (REPO / "mcp/mcp-servers.json").write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n")


def write_shell() -> None:
    say("shell/zshrc-claude.zsh")
    d = REPO / "shell"
    d.mkdir(exist_ok=True)
    (d / "zshrc-claude.zsh").write_text(
        "# Append to ~/.zshrc (or the equivalent for your shell).\n"
        "# `claude` launches with function hooks on so the jev-compact plugin can take over compaction;\n"
        "# the plugin reads TYPESAFE_API_KEY from ~/.env itself — nothing is exported into the process env.\n"
        "claude() {\n  CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1 command claude \"$@\"\n}\n"
        "alias claude-plain='command claude'                       # without function hooks\n"
        "alias lawde='claude --dangerously-skip-permissions'       # when you really mean it\n"
    )


# ---------------------------------------------------------------- manifest
def plugin_catalog() -> tuple[list[dict], dict[str, str]]:
    settings = json.loads((C / "settings.json").read_text())
    enabled = {k: v for k, v in settings.get("enabledPlugins", {}).items()}
    markets: dict[str, str] = {}
    km = C / "plugins/known_marketplaces.json"
    if km.exists():
        try:
            for name, m in json.loads(km.read_text()).items():
                src = m.get("source", m) if isinstance(m, dict) else {}
                if src.get("source") == "directory":
                    markets[name] = str(src.get("path", "")).replace(str(HOME), "<HOME>") + " (local clone — see the plugins notes)"
                else:
                    markets[name] = src.get("repo") or src.get("url") or str(src)
        except (json.JSONDecodeError, AttributeError):
            pass
    catalog = []
    cache = C / "plugins/cache"
    for key, on in sorted(enabled.items()):
        plugin, _, market = key.partition("@")
        versions = sorted((cache / market / plugin).glob("*"), key=lambda p: p.stat().st_mtime) if (cache / market / plugin).is_dir() else []
        root = versions[-1] if versions else None
        version = ""
        if root and (root / ".claude-plugin/plugin.json").exists():
            try:
                version = json.loads((root / ".claude-plugin/plugin.json").read_text()).get("version", "")
            except json.JSONDecodeError:
                pass
        skills = []
        commands = []
        if root:
            for sk in sorted((root / "skills").glob("*/SKILL.md")):
                fm = frontmatter(sk)
                skills.append({"invoke": f"{plugin}:{fm.get('name') or sk.parent.name}", "description": short(fm.get("description", ""))})
            commands = sorted(f"/{p.stem}" for p in (root / "commands").glob("*.md"))
        install = f"/plugin install {key}"
        if market not in ("claude-plugins-official",):
            install = f"claude plugin marketplace add {markets.get(market, market)} && " + install
        catalog.append({"plugin": plugin, "marketplace": market, "marketplace_source": markets.get(market, ""), "enabled": bool(on),
                        "install": install, "version": version, "macos_only": plugin in ("imessage", "swift-lsp"),
                        "skills": skills, "commands": commands,
                        "userConfig": settings.get("pluginConfigs", {}).get(key, {}).get("options")})
    return catalog, markets


def build_manifest() -> None:
    say("manifest.json")
    old = json.loads((REPO / "manifest.json").read_text()) if (REPO / "manifest.json").exists() else {}
    by_id = {c["id"]: c for c in old.get("components", [])}

    def comp(cid: str, **fields):
        base = dict(by_id.get(cid, {}))
        base.update(fields)
        base["id"] = cid
        return base

    skills = []
    for sk in sorted((REPO / "claude/skills").glob("*/SKILL.md")):
        fm = frontmatter(sk)
        skills.append({"name": sk.parent.name, "description": short(fm.get("description", ""))})
    catalog, markets = plugin_catalog()
    enabled_plugins = [c for c in catalog if c["enabled"]]
    scripts = sorted(p.name for p in (REPO / "claude/scripts").iterdir() if p.is_file())
    tools = sorted(p.name for p in (REPO / "bin").iterdir() if p.is_file())
    jobs = sorted(p.name for p in (REPO / "launchd").glob("*.plist"))

    components = [
        comp("core-settings", payload=["claude/settings.json", "claude/settings.local.json"]),
        comp("global-claude-md", payload=["claude/CLAUDE.md", "extras/harsha-slack-writing-style.md"]),
        comp("skills", label=f"Personal skills ({len(skills)}) — copied from this repo into ~/.claude/skills/", payload=["claude/skills/"],
             target="~/.claude/skills/", default=True, sub_selectable=True, items=skills),
        comp("agents", payload=["claude/agents/"]),
        comp("commands", payload=["claude/commands/"]),
        comp("hook-scripts", label=f"Hook + automation scripts ({len(scripts)}) — malware guards, PR babysitter, Jev risk gate, triage runners, mem-guard, TCC cleaner",
             payload=["claude/scripts/"], items=scripts,
             notes="Wired from settings.json hooks and from launchd/. The Jev scripts need bin/jev-ask + TYPESAFE_API_KEY in ~/.env; everything fails open without it. "
                   "The malware IOC data files (malware-ioc-canonical.txt, malware-ioc-bundle-exclude.txt, malware-guard-targets.txt) are NOT exported — sync-malware-iocs.py regenerates the guards from a local list."),
        comp("cli-tools", label=f"CLI tools ({len(tools)}) — with-env / env-sync (universal ~/.env), jev-ask, jev-step, jab, jev-replicate",
             payload=["bin/"], target="~/.local/bin/ (chmod +x; must be on PATH)", default=True, items=tools,
             notes="with-env reads ~/.env (mode 600, [owner] blocks) — create it with at least `[personal]\\nTYPESAFE_API_KEY=...`. jev-step/jab need agent-browser + hunch (`uv tool install hunch-browser` or from github.com/HAR5HA-7663/hunch)."),
        comp("launchd-jobs", label=f"Scheduled jobs ({len(jobs)}, macOS launchd) — brain watcher/sync, daily brain sync, malware sweep, mem-guard, morning/monday triage",
             payload=["launchd/"], target="~/Library/LaunchAgents/ then `launchctl load`", default=False, items=jobs,
             notes="Paths inside are /Users/HAR5HA — rewrite to the new home. Only ONE machine should run daily-brain-sync and the triage jobs. Linux: systemd user units; Windows: Task Scheduler."),
        comp("shell", label="Shell launcher — `claude` with function hooks (needed by the jev-compact plugin), `claude-plain`, `lawde`",
             payload=["shell/zshrc-claude.zsh"], target="append to ~/.zshrc", default=True),
        comp("statusline", payload=["claude/statusline-custom.sh", "claude/statusline.sh", "claude/statusline/"]),
        comp("plugins", label=f"Plugins ({len(enabled_plugins)} enabled) — these ship their OWN skills; nothing to copy, install via /plugin",
             payload=[], target=None, default=True, sub_selectable=True, catalog=catalog, marketplaces=markets,
             notes="jev-compact is Harsha's own plugin (github.com/HAR5HA-7663/jev-compact): clone it, `claude plugin marketplace add <clone dir>`, then install with the userConfig shown. It needs CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1 (see shell/) and TYPESAFE_API_KEY in ~/.env."),
        comp("mcp-servers", payload=["mcp/mcp-servers.json"]),
        comp("external-tools", payload=["external-deps.md"]),
        comp("brain-system", payload=[]),
    ]
    manifest = {
        "name": old.get("name", "My_Claude_Setup"),
        "owner": old.get("owner", "HAR5HA-7663"),
        "exported": old.get("exported", TODAY),
        "updated": TODAY,
        "source_machine": f"macOS ({os.uname().sysname.lower()} {os.uname().release}), Claude Code {claude_version()}",
        "install_doc": "INSTALL_AGENT.md",
        "export_script": "export.py",
        "components": components,
        "counts": {
            "personal_skills": len(skills),
            "plugins": len(enabled_plugins),
            "plugin_skills": sum(len(c["skills"]) for c in enabled_plugins),
            "plugin_commands": sum(len(c["commands"]) for c in enabled_plugins),
            "hook_scripts": len(scripts),
            "cli_tools": len(tools),
            "launchd_jobs": len(jobs),
        },
    }
    (REPO / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")


def claude_version() -> str:
    try:
        out = subprocess.run(["claude", "--version"], capture_output=True, text=True, timeout=20).stdout
        m = re.search(r"\d+\.\d+\.\d+", out)
        return m.group(0) if m else "unknown"
    except (OSError, subprocess.TimeoutExpired):
        return "unknown"


# ---------------------------------------------------------------- secret scan
def scan() -> int:
    hits = 0
    for path in REPO.rglob("*"):
        if not path.is_file() or ".git" in path.parts or path.suffix in (".png", ".gif", ".jpg", ".woff2", ".pyc"):
            continue
        try:
            text = path.read_text(errors="replace")
        except OSError:
            continue
        for i, line in enumerate(text.splitlines(), 1):
            for pat in SECRET_PATTERNS:
                if pat.search(line) and not SECRET_ALLOW.search(line):
                    hits += 1
                    print(f"SECRET? {path.relative_to(REPO)}:{i}: {line.strip()[:120]}")
                    break
    if (REPO / ".env").exists() or list(REPO.rglob("*.env")):
        print("SECRET? an .env file is inside the repo")
        hits += 1
    return hits


def main() -> int:
    os.chdir(REPO)
    if "--check" not in sys.argv:
        print("== export from live setup")
        sync_claude_dir()
        sync_bin()
        sync_launchd()
        sync_mcp()
        write_shell()
        build_manifest()
    print("== secret scan")
    n = scan()
    print("  clean" if n == 0 else f"  {n} suspicious line(s) — fix before pushing")
    return 1 if n else 0


if __name__ == "__main__":
    sys.exit(main())
