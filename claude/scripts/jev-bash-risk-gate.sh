#!/bin/bash
# jev-bash-risk-gate.sh — PreToolUse hook (Bash): a semantic second opinion on every command.
#
# The regex guards (malware IOCs, npm precheck) catch known bad strings. This gate only
# cares about CATASTROPHES (policy 2026-10-13, Harsha: "only high security and malware
# incidents, or my agent removing all the project files / deleting the database"):
#
#   deny  - deleting a protected root (home, Desktop, a project dir, a git repo root, its
#           src tree, ~/.claude, ~/brain, ~/.env, ~/.ssh); dropping a non-local database;
#           disabling this machine's own guards or loosening key permissions; sending secret
#           material to a host that is none of the developer's services; force-push /
#           branch delete on main, master or staging.
#   ask   - force-push on harsha-dev / lab-staging; curl-pipe-to-shell from an unknown host;
#           and whatever Jev rates >= ASK_P when consulted.
#   Jev   - consulted ONLY for grey-zone destruction (rm -r of a real directory outside
#           scratch, DROP TABLE / TRUNCATE / DELETE-without-WHERE against a non-local DB,
#           git clean, discarding a whole working tree): one question, "would this wipe out a
#           project, repository, database or production resource beyond easy recovery?"
#           p >= DENY_P deny, p >= ASK_P ask, else allow.
#   allow - everything else, silently and without a network call: sudo, ssh/scp/rsync to any
#           host, installs, kills, chmod, API calls, remote admin, the lot.
#
# Fails OPEN: no key, no network, timeout, or JEV_OFF=1 means the command proceeds.
# Secrets in the command are masked by jev-ask before anything is sent.
#
# Tune in ~/.config/jev-gate.env:   DENY_P=0.85  ASK_P=0.60  DEADLINE_MS=900  GATE_OFF=0
# Log: ~/.local/state/jev/bash-gate.log (masked command, verdict). Never blocks on its own bugs.
set -u

IN=$(cat 2>/dev/null || true)
[ -n "$IN" ] || exit 0
CMD=$(printf '%s' "$IN" | jq -r '.tool_input.command // ""' 2>/dev/null || true)
[ -n "$CMD" ] || exit 0

DENY_P=0.85; ASK_P=0.60; DEADLINE_MS=900; GATE_OFF=0
[ -f "$HOME/.config/jev-gate.env" ] && . "$HOME/.config/jev-gate.env"
[ "$GATE_OFF" = "1" ] && exit 0
[ -n "${EXTRA_ALLOW_RE:-}" ] && printf "%s" "$CMD" | grep -qE "$EXTRA_ALLOW_RE" && exit 0
command -v jev-ask >/dev/null 2>&1 || PATH="$HOME/.local/bin:$PATH"
command -v jev-ask >/dev/null 2>&1 || exit 0

STATE_DIR="$HOME/.local/state/jev"; mkdir -p "$STATE_DIR"
GLOG="$STATE_DIR/bash-gate.log"
[ -f "$GLOG" ] && [ "$(wc -l < "$GLOG")" -gt 20000 ] && { tail -n 10000 "$GLOG" > "$GLOG.tmp" && mv "$GLOG.tmp" "$GLOG"; }

# ---- local fast path: obviously read-only commands never leave the machine ----
# Every segment (split on ; && || |) must start with a read-only verb and the whole
# command must contain no write/redirect/sudo tokens.
readonly_verbs='^[[:space:]]*(ls|ll|cat|head|tail|less|more|wc|grep|rg|egrep|fgrep|find|fd|stat|file|du|df|pwd|echo|printf|date|whoami|id|uname|which|type|command|env|printenv|tree|jq|yq|sort|uniq|cut|tr|awk|sed -n|diff|cmp|md5|shasum|sha256sum|basename|dirname|realpath|readlink|test|\[|true|false|sleep|ps|pgrep|lsof|netstat|uptime|sysctl -n|git (status|log|diff|show|branch|remote -v|rev-parse|ls-files|blame|describe|tag$|stash list|worktree list)|gh (pr view|pr list|pr checks|pr diff|issue view|issue list|run list|run view|repo view|api graphql -f query=\{ ?repository)|npm (ls|list|view|outdated)|pnpm (ls|list)|python3? -c ["'"'"']print|node -e ["'"'"']console|curl -s(S)? -o /dev/null|with-env --(list|blocks|has)|jev-ask|agent-browser (snapshot|get|is|screenshot)|hunch --dry-run)'
if ! printf '%s' "$CMD" | grep -qE '(>|>>|\bsudo\b|\brm\b|\bmv\b|\bdd\b|\bchmod\b|\bchown\b|\bkill|\btruncate\b|\bshred\b|\blaunchctl\b|\bdefaults write|\bsecurity\b|\bxargs\b|\bcurl\b.*\|\s*(ba|z)?sh|\bwget\b|\bgit (push|reset|rebase|checkout|restore|clean|branch -[dD]|tag -d|stash (drop|clear))|--force|-f\b|\btee\b|\bcp\b|\bln\b|\binstall\b|\bpip\b|\bnpm (i|install|publish|run)|\bpnpm (add|install|publish)|\bbrew\b|\bdocker\b|\bpsql\b|\bmysql\b|\bssh\b|\bscp\b|\brsync\b|\bosascript\b|\bcrontab\b|\bpython3? [^-]|\bnode [^-]|\bbash |\bsh |\bzsh |\beval\b|\bexport\b|\bset -)'; then
  all_ro=1
  while IFS= read -r seg; do
    [ -z "${seg// /}" ] && continue
    printf '%s' "$seg" | grep -qE "$readonly_verbs" || { all_ro=0; break; }
  done < <(printf '%s' "$CMD" | sed -E 's/\|\||&&|;|\|/\n/g')
  [ "$all_ro" = "1" ] && exit 0
fi

# ---- standing allow: team channels + ordinary git, when the command carries no force/delete/secret-read ----
if printf '%s' "$CMD" | grep -qE '(^|[;&|[:space:]])(tg (send|read)|slack (send|post)|pr-review-bot|gh (pr|issue) (create|edit|comment|review|merge|ready|close|reopen)|git push)[[:space:]]' \
   && ! printf '%s' "$CMD" | grep -qE '(--force|-f\b|--delete|-D\b|\brm\b|\bsudo\b|\bcurl\b|\bwget\b|\bscp\b|\brsync\b|~/\.env|/\.ssh/|credentials?\.|\.session\b|security find)' \
   && ! printf '%s' "$CMD" | grep -qE 'git push[^;&|]*[[:space:]]:(main|master|staging|lab-staging)\b'; then
  printf '%s %-5s %s :: %s\n' "$(date '+%F %T')" allow "standing: team channel / git" "$(printf '%s' "$CMD" | tr '\n' ' ' | cut -c1-200)" >> "$GLOG"
  exit 0
fi

# ---- context ----
CWD=$(printf '%s' "$IN" | jq -r '.cwd // ""' 2>/dev/null); [ -n "$CWD" ] || CWD="$PWD"
BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "-")
MASKED=$(printf '%s' "$CMD" | tr '\n' ' ' | cut -c1-200)
log() { printf '%s %-5s %s :: %s\n' "$(date '+%F %T')" "$1" "$2" "$MASKED" >> "$GLOG"; }
emit() {  # verdict reason
  local r="jev-gate: $2. $( [ "$1" = "deny" ] && echo "Blocked. If it is really needed, explain to Harsha what it does and let him run it, or find a reversible way (backup first, dry-run, scratch copy)." || echo "Asking Harsha before running it." )"
  jq -n --arg d "$1" --arg r "$r" --arg s "jev-gate ${1}: $2 — ${MASKED:0:80}" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r},systemMessage:$s}'
}
verdict=allow; why=""; needs_jev=0; jev_why=""
lc=$(printf '%s' "$CMD" | tr 'A-Z' 'a-z')

# ---- 1. own guards / security posture (deny) ----
if printf '%s' "$CMD" | grep -qE 'launchctl[[:space:]]+(unload|bootout|disable|remove)[^;&|]*com\.harsha\.(malware-sweep|mem-guard|brain-watch|daily-brain-sync|brain-sync)'; then verdict=deny; why="disables one of this machine's own guards"
elif printf '%s' "$CMD" | grep -qE 'chmod[[:space:]]+(-R[[:space:]]+)?([0-7]?[0-7][4-7][4-7]|[augo]*\+[rwxX]*[rw][rwxX]*)[^;&|]*(/\.env\b|\.ssh/|\.ssh\b)'; then verdict=deny; why="loosens permissions on keys or ~/.env"
elif printf '%s' "$lc" | grep -qE 'csrutil disable|spctl --master-disable|socketfilterfw[^;&|]*(--setglobalstate off|--setstealthmode off)|defaults write[^;&|]*com\.apple\.(security|screensaver)|tccutil reset'; then verdict=deny; why="weakens macOS security settings"
elif printf '%s' "$CMD" | grep -qE '(jq|sed|python3?|perl|node)[^;&|]*\.claude/settings\.json' && printf '%s' "$CMD" | grep -qE '"?hooks"?' && printf '%s' "$CMD" | grep -qE '(del\(|delete|-i|> *[^ ]*settings\.json|write)'; then verdict=ask; why="edits the hook wiring in ~/.claude/settings.json"
fi

# ---- 2. secret material to an unknown host (deny) ----
KNOWN_HOSTS_RE='(github\.com|githubusercontent\.com|slack\.com|api\.telegram\.org|t\.me|cloudflare\.com|modal\.com|modal\.run|vercel\.com|vercel\.app|supabase\.(co|com)|stripe\.com|googleapis\.com|google\.com|monday\.com|typesafe\.ai|anthropic\.com|openai\.com|deepgram\.com|fish\.audio|assemblyai\.com|twilio\.com|signalhouse|bevri\.ai|teli\.ai|ltu\.edu|amazonaws\.com|fly\.io|localhost|127\.0\.0\.1|172\.16\.2\.|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.|\.ts\.net|\.local\b|^homepc$|^goat$|^pimolt$|^tvpi$)'
SECRET_SRC_RE='(~/\.env\b|\$HOME/\.env\b|/\.ssh/id_(rsa|ed25519|ecdsa)([^.a-z]|$)|\.clasprc|\.netrc|\.aws/credentials|security find-generic-password|credentials?\.(txt|json|md)|\.pem\b|[a-z-]*token\b[^;&|]*\|[[:space:]]*curl|\.session\b)'
if [ "$verdict" = "allow" ] && printf '%s' "$CMD" | grep -qE "$SECRET_SRC_RE"; then
  # only real destinations: URLs, or user@host where host is a dotted name / IP (not `@-`, `@file`)
  hosts=$(printf '%s' "$CMD" | grep -oE '(https?://[a-zA-Z0-9._-]+|[a-zA-Z0-9._-]+@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+)' | sed -E 's#^https?://##; s#^[^@]*@##' | tr 'A-Z' 'a-z' | sort -u)
  unknown=$(printf '%s\n' "$hosts" | grep -vE "$KNOWN_HOSTS_RE" | grep -vE '^$' || true)
  [ -n "$unknown" ] && { verdict=deny; why="sends secret material to $(printf '%s' "$unknown" | head -1)"; }
fi

# ---- 3. git history on shared branches ----
if [ "$verdict" = "allow" ] && printf '%s' "$CMD" | grep -qE 'git[[:space:]]+(push[^;&|]*(--force|-f\b|--delete|-d\b|[[:space:]]\+)|branch[[:space:]]+-D|push[^;&|]*--force-with-lease)'; then
  seg=$(printf '%s' "$CMD" | tr ';&|' '\n\n\n' | grep -E 'git[[:space:]]+(push|branch)')
  tgt=$(printf '%s' "$seg" | grep -oE '(main|master|staging|lab-staging|harsha-dev)\b' | head -1)
  [ -z "$tgt" ] && printf '%s' "$BRANCH" | grep -qE '^(main|master|staging|lab-staging|harsha-dev)$' && tgt="$BRANCH"
  case "$tgt" in
    main|master|staging) verdict=deny; why="rewrites or deletes shared branch $tgt" ;;
    lab-staging|harsha-dev) verdict=ask; why="force-push / delete on $tgt" ;;
  esac
fi

# ---- 4. mass deletion: protected roots deny, real directories outside scratch go to Jev ----
if [ "$verdict" = "allow" ] && printf '%s' "$CMD" | grep -qE '(^|[;&|[:space:]])(rm|rmdir|trash)[[:space:]]|find[^;&|]*-delete|git[[:space:]]+clean|git[[:space:]]+(checkout|restore)[[:space:]]+(--[[:space:]]+)?\.([[:space:]]|$)'; then
  cls=$(CWD="$CWD" CMD="$CMD" python3 - <<'PY'
import os, re, sys
home = os.path.expanduser("~"); cwd = os.environ["CWD"]; cmd = os.environ["CMD"]
protected = {"/", home, f"{home}/Desktop", f"{home}/Documents", f"{home}/Library", f"{home}/Applications", f"{home}/brain",
             f"{home}/.claude", f"{home}/.env", f"{home}/.ssh", f"{home}/.config", f"{home}/.local", f"{home}/tools",
             f"{home}/Desktop/Bevri", f"{home}/Desktop/teli", f"{home}/Desktop/Personal", f"{home}/Desktop/Documents",
             f"{home}/Desktop/Archive", f"{home}/Desktop/Bevri-context", f"{home}/Desktop/ActionLabs"}
scratch = re.compile(r"((^|/)(tmp|temp|scratch[^/]*|scratchpad|node_modules|\.next|\.turbo|\.cache|dist|build|out|coverage|__pycache__|\.pytest_cache|logs?|worktrees)(/|$)|^/private/tmp/|^/tmp/|^/var/folders/|/\.claude/jobs/[^/]+/tmp(/|$)|\.(log|tmp|bak[^/]*|pyc|orig|rej)$)")
srcdirs = {"src", "app", "lib", "packages", "api", "web", "server", "frontend", "backend", "services", "migrations", "prisma", "components", "pages"}
worst = "ok"; detail = ""
def rank(level, why):
    global worst, detail
    order = {"ok": 0, "jev": 1, "deny": 2}
    if order[level] > order[worst]: worst, detail = level, why
segs = re.split(r"[;&|]+", cmd)
for seg in segs:
    seg = seg.strip()
    m = re.match(r"^(rm|rmdir|trash)\s+(.*)$", seg)
    if m:
        toks = [t for t in re.split(r"\s+", m.group(2)) if t and not t.startswith("-")]
        for t in toks:
            t = os.path.expanduser(t.strip("'\""))
            if "$" in t and not t.startswith("$HOME"): rank("jev", f"variable path {t}"); continue
            t = t.replace("$HOME", home)
            path = os.path.normpath(t if t.startswith("/") else os.path.join(cwd, t))
            base = path.rstrip("*")
            if t in ("*", "./*", ".", "./") or path.endswith("/*"):
                path = cwd if t in ("*", "./*", ".", "./") else os.path.dirname(path)
            if path in protected or any(path == p or path.startswith(p + "/") and p in (f"{home}/.claude", f"{home}/.ssh", f"{home}/brain") for p in protected):
                rank("deny", f"protected path {path}"); continue
            if scratch.search(path): continue
            if os.path.isdir(os.path.join(path, ".git")): rank("deny", f"git repository {path}"); continue
            parent = os.path.dirname(path)
            if os.path.isdir(os.path.join(parent, ".git")) and os.path.basename(path) in srcdirs: rank("deny", f"source tree {path}"); continue
            if os.path.basename(path) == ".git" or re.match(r"^\.env(\.|$)", os.path.basename(path)): rank("deny", f"{path}"); continue
            if os.path.isdir(path):
                n = 0
                for _, _, files in os.walk(path):
                    n += len(files)
                    if n > 25: break
                if n > 25: rank("jev", f"directory {path} ({n}+ files)")
            # single files / small dirs / non-existent paths: fine
    elif re.search(r"find\b.*-delete", seg):
        rank("jev", "find -delete")
    elif re.search(r"git\s+clean", seg) and os.path.isdir(os.path.join(cwd, ".git")) and not scratch.search(cwd):
        rank("jev", "git clean in a real checkout")
    elif re.search(r"git\s+(checkout|restore)\s+(--\s+)?\.(\s|$)", seg) and not scratch.search(cwd):
        rank("jev", "discards the whole working tree")
print(worst + "|" + detail)
PY
)
  case "${cls%%|*}" in
    deny) verdict=deny; why="would delete ${cls#*|}" ;;
    jev) needs_jev=1; jev_why="${cls#*|}" ;;
  esac
fi

# ---- 5. databases: non-local wipes deny, table-level destruction goes to Jev ----
if [ "$verdict" = "allow" ]; then
  local_db=0; printf '%s' "$lc" | grep -qE 'localhost|127\.0\.0\.1|docker (exec|compose)|host=db\b|@db:|@postgres:|@redis:|test\.db|\.sqlite' && local_db=1
  if printf '%s' "$lc" | grep -qE '\bdrop[[:space:]]+(database|schema)\b|\bdropdb\b|db\.dropdatabase|\bflushall\b|\bflushdb\b|supabase db reset|prisma migrate reset|--force-reset|rails db:drop|(gcloud sql instances|aws rds|aws dynamodb) delete|aws s3 (rb|rm[^;&|]*--recursive)|gsutil (rm -r|rb)|az [a-z ]*db[a-z ]* delete'; then
    [ "$local_db" = "1" ] || { verdict=deny; why="drops a database or storage that is not local"; }
  elif printf '%s' "$lc" | grep -qE '\bdrop[[:space:]]+table\b|\btruncate\b|\bdelete[[:space:]]+from[[:space:]]+[a-z_."]+[[:space:]]*(;|$|\\n|'"'"'|")' ; then
    [ "$local_db" = "1" ] || { needs_jev=1; jev_why="table-level destruction on a non-local database"; }
  fi
fi

# ---- 6. remote code from an unknown host (ask) ----
if [ "$verdict" = "allow" ] && printf '%s' "$CMD" | grep -qE '(curl|wget)[^;&|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z)?sh\b'; then
  h=$(printf '%s' "$CMD" | grep -oE 'https?://[a-zA-Z0-9._-]+' | sed -E 's#^https?://##' | tr 'A-Z' 'a-z' | grep -vE "$KNOWN_HOSTS_RE|brew\.sh|rustup\.rs|astral\.sh|deno\.land|bun\.sh|get\.docker\.com|nodesource\.com|tailscale\.com|ollama\.(ai|com)" | head -1)
  [ -n "$h" ] && { verdict=ask; why="pipes a script from $h straight into a shell"; }
fi

# ---- 7. Jev, only for the grey zone ----
if [ "$verdict" = "allow" ] && [ "$needs_jev" = "1" ]; then
  REPO=$(git -C "$CWD" remote get-url origin 2>/dev/null | sed -E -e 's#\.git$##' -e 's#.*[:/]([^/]+/[^/]+)$#\1#')
  STATE="A coding assistant on a developer's macOS laptop is about to run this shell command. Working directory: ${CWD/#$HOME/\~}. Git repo: ${REPO:-none}, branch ${BRANCH}.
Scratch material (tmp/, scratch dirs, worktrees, build output, caches, logs, node_modules, local dev databases, redis keys, single files) is disposable and its loss is trivial. The developer only wants to be interrupted when an ENTIRE project, repository, source tree, database, or production resource would be wiped out beyond easy recovery.
Flagged because: ${jev_why}.

COMMAND:
${CMD}"
  ANS=$(printf '%s' "$STATE" | jev-ask --purpose bash-gate --deadline "$DEADLINE_MS" \
    --noul catastrophic "Would running COMMAND wipe out an entire project, repository, source tree, database, or production resource that could not be easily restored?" 2>/dev/null)
  P=$(printf '%s' "$ANS" | jq -r '.catastrophic.noul // empty' 2>/dev/null)
  if [ -n "$P" ]; then
    if [ "$(printf '%s >= %s\n' "$P" "$DENY_P" | bc -l)" = "1" ]; then verdict=deny; why="Jev p(catastrophic)=$P: $jev_why"
    elif [ "$(printf '%s >= %s\n' "$P" "$ASK_P" | bc -l)" = "1" ]; then verdict=ask; why="Jev p(catastrophic)=$P: $jev_why"
    else why="jev p=$P ok: $jev_why"; fi
  else why="jev unavailable, allowed: $jev_why"; fi
fi

log "$verdict" "${why:-ok}"
[ "$verdict" = "allow" ] && exit 0
emit "$verdict" "$why"
exit 0
