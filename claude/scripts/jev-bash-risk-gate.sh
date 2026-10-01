#!/bin/bash
# jev-bash-risk-gate.sh — PreToolUse hook (Bash): a semantic second opinion on every command.
#
# The regex guards (malware IOCs, npm precheck) catch known bad strings. This asks Jev,
# TypeSafe's decision model, whether the command would destroy data, rewrite shared git
# history, weaken this machine's security, or send data off it — in ~300 ms, before it runs.
#
#   p(risky) >= DENY_P  -> deny (Claude sees why and must find another way / ask you)
#   p(risky) >= ASK_P   -> ask  (you get the normal permission prompt, with Jev's reason)
#   otherwise           -> allow silently
#
# It can only ADD a block; the regex guards' decisions stand. Fails OPEN: no key, no
# network, timeout, or JEV_OFF=1 means the command proceeds as before. Read-only commands
# are recognised locally and never sent (no latency, nothing leaves the machine).
# Secrets in the command are masked by jev-ask before it is sent.
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

# ---- context for the judgement (cwd, repo, branch) ----
CWD=$(printf '%s' "$IN" | jq -r '.cwd // ""' 2>/dev/null); [ -n "$CWD" ] || CWD="$PWD"
BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "-")
REPO=$(git -C "$CWD" remote get-url origin 2>/dev/null | sed -E -e 's#\.git$##' -e 's#.*[:/]([^/]+/[^/]+)$#\1#')
HOME_REL=${CWD/#$HOME/\~}

STATE="A coding assistant on a developer's macOS laptop is about to run this shell command.
Working directory: ${HOME_REL}
Git repo: ${REPO:-none}   current branch: ${BRANCH}
Shared branches that other people depend on: main, master, staging, lab-staging, harsha-dev. Committing and pushing new commits (without --force) to ANY branch, including those, is ordinary work; only force-pushing, resetting, rebasing already-pushed commits, or deleting a shared branch counts as rewriting history.
Standing-authorised, ordinary work (never exfiltration): git push / gh pr create, edit, merge, comment, review on the developer's own repos; gh secret set on his own repos; sending messages to his own team or his review bots with the tg CLI (Telegram), the slack CLI, Slack webhooks or the Slack/Monday/GitHub APIs; uploading files into his own web apps (bevri.ai, teli.ai, staging/lab hosts) with agent-browser; calls to services he operates (Cloudflare, Modal, Vercel, Supabase, Stripe, Google APIs). Exfiltration means sending credentials or private data to a host that is none of these.
The laptop runs this developer's own security guards (launchd agents named malware-sweep, mem-guard, brain-watch; hook scripts under ~/.claude/scripts) which must not be disabled.
The developer's OWN other machines, on his office LAN: goat@goats-Mac-mini.local / goat@172.16.2.106 (his Mac mini — the IP changes, the .local name does not), pi@172.16.2.63 (his office TV Raspberry Pi), pimolt@172.16.2.96 / pimolt.local (his brain Raspberry Pi). Copying files or running commands on these with ssh, scp or rsync is ordinary work, not exfiltration. The developer has standing-authorised the assistant to hand long-running jobs to the Mac mini: copying a script plus a private (mode 600) env file of credentials there, and starting it, including scripts that log in to the developer's own web apps with his own test accounts, is ordinary work. Sending data to any other remote host is exfiltration.

COMMAND:
${CMD}"

ANS=$(printf '%s' "$STATE" | jev-ask --purpose bash-gate --deadline "$DEADLINE_MS" \
  --noul risky "Would running COMMAND cause a loss that the developer could not easily undo?" \
  --noul routine "Is COMMAND an ordinary development action such as building, testing, linting, reading, formatting, installing dependencies, committing, or pushing to a personal feature branch?" \
  --noul disposable "If COMMAND deletes or overwrites anything, is it only build output, caches, temp or scratch files and directories (anything under a tmp/, scratch or worktrees path, or under /private/tmp), logs, node_modules, local dev-server processes, or other things that are trivially regenerated?" \
  --noul remote_code "Does COMMAND fetch a script from a URL with curl, wget or similar and pipe or execute it in the same command? Package managers such as npm, pnpm, pip, uv, brew and cargo do not count." \
  --choice kind "Which best describes COMMAND?" benign="builds, tests, reads, edits, installs, commits, or pushes to a personal feature branch" destructive_fs="deletes, overwrites, truncates or formats files, directories, volumes or databases" git_history="force-pushes, resets or rewrites history on a shared branch (main, master, staging, lab-staging, harsha-dev), or deletes branches or tags others may use" security_downgrade="disables a guard or launchd agent, loosens permissions on keys or credentials, or changes security settings" exfiltration="uploads or sends local files, secrets or data to a remote host or service" privilege="uses sudo or changes system-level configuration" 2>/dev/null)
RC=$?
[ "$RC" -eq 0 ] && [ -n "$ANS" ] || exit 0   # Jev unavailable: fail open, regex guards still apply

read -r P_RISKY P_ROUTINE P_DISP P_REMOTE KIND KIND_CONF < <(printf '%s' "$ANS" | jq -r '[(.risky.noul // 0), (.routine.noul // 0), (.disposable.noul // 1), (.remote_code.noul // 0), (.kind.choice // "unknown"), (.kind.confidence // 0)] | @tsv' 2>/dev/null | tr '\t' ' ')
[ -n "${P_RISKY:-}" ] || exit 0
ge() { [ "$(printf '%s >= %s\n' "$1" "$2" | bc -l 2>/dev/null)" = "1" ]; }
lt() { [ "$(printf '%s < %s\n' "$1" "$2" | bc -l 2>/dev/null)" = "1" ]; }

MASKED=$(printf '%s' "$CMD" | tr '\n' ' ' | cut -c1-200)
# Two independent signals decide: Jev's overall p(risky) and its confident category. Either is
# enough. Destructive commands are excused when the target is disposable (node_modules, /tmp).
verdict=allow; why=""
# Deterministic: a command whose every ssh/scp/rsync target is one of the developer's own
# machines is not exfiltration, whatever Jev's wording of it (standing permission 2026-09-25).
# Only the exfiltration label is excused — destructive / git-history / sudo checks still apply.
OWN_HOSTS='^([a-z0-9._-]+@)?(goats-mac-mini\.local|172\.16\.2\.106|172\.16\.2\.63|172\.16\.2\.96|pimolt\.local)(:.*)?$'
own_only=0
if [ "$KIND" = "exfiltration" ] && printf '%s' "$CMD" | grep -qE '(^|[;&|[:space:]])(ssh|scp|rsync)[[:space:]]'; then
  targets=$(printf '%s' "$CMD" | tr ' "'"'"'' '\n\n\n' | grep -E '^[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+(:.*)?$' | tr 'A-Z' 'a-z')
  if [ -n "$targets" ] && ! printf '%s\n' "$targets" | grep -vqE "$OWN_HOSTS"; then own_only=1; KIND="benign"; why="own machine"; fi
fi
# Known destinations the developer sends to every day. "exfiltration" only stands when the command
# both reads secret material AND reaches a host outside this list; otherwise it is ordinary work
# (standing permission 2026-10-01: Slack / Telegram / git / gh must not be blocked).
KNOWN_HOSTS_RE='(github\.com|githubusercontent\.com|slack\.com|api\.telegram\.org|t\.me|cloudflare\.com|modal\.com|modal\.run|vercel\.com|vercel\.app|supabase\.(co|com)|stripe\.com|googleapis\.com|google\.com|monday\.com|typesafe\.ai|anthropic\.com|bevri\.ai|teli\.ai|signalhouse|localhost|127\.0\.0\.1|172\.16\.2\.|\.local\b)'
SECRET_SRC_RE='(~/\.env\b|\$HOME/\.env\b|/\.ssh/|\.clasprc|\.netrc|\.aws/credentials|security find-generic-password|credentials?\.(txt|json|md)|id_(rsa|ed25519)|\.pem\b|cloudflare-[a-z-]*token|\.session\b)'
MSG_CLI_RE='(^|[;&|[:space:]])(tg (send|read|whoami)|slack (send|post|chat)|pr-review-bot|gh (pr|issue|secret|release|api|run|workflow)|git (push|commit|add|fetch|pull|merge|checkout|switch|branch|tag|stash|worktree|cherry-pick))[[:space:]]'
if [ "$KIND" = "exfiltration" ] && [ "$own_only" != "1" ]; then
  hosts=$(printf '%s' "$CMD" | grep -oE '(https?://|@)[a-zA-Z0-9._-]+' | sed -E 's#^(https?://|@)##' | tr 'A-Z' 'a-z' | sort -u)
  unknown=$(printf '%s\n' "$hosts" | grep -vE "$KNOWN_HOSTS_RE" | grep -vE '^$' || true)
  reads_secret=0; printf '%s' "$CMD" | grep -qE "$SECRET_SRC_RE" && reads_secret=1
  if [ -z "$unknown" ] || [ "$reads_secret" = "0" ]; then
    if [ -n "$unknown" ]; then KIND="unknown_host"; why="sends to $(printf '%s' "$unknown" | head -1)"; else KIND="benign"; why="known service"; fi
  fi
fi
# Plain commits/pushes are never "history": only an explicit force / reset / rebase / delete on a shared branch is.
SHARED_RE='(main|master|staging|lab-staging|harsha-dev)'
if [ "$KIND" = "git_history" ]; then
  if printf '%s' "$CMD" | grep -qE "git push[^;&|]*(--force|-f\b|--delete|-d\b|:$SHARED_RE|\+$SHARED_RE)|git (reset --hard|rebase|filter-branch|filter-repo)[^;&|]*|git branch -[dD][^;&|]*$SHARED_RE|git push[^;&|]*--force-with-lease" && \
     { printf '%s' "$CMD" | grep -qE "$SHARED_RE" || printf '%s' "$BRANCH" | grep -qE "^$SHARED_RE$"; }; then :
  else KIND="benign"; why="ordinary git"; fi
fi
# Deleting scratch material is not destructive: every rm target under a scratch root (tmp/, scratch*,
# build output, caches, session job dirs, logs/backups) excuses the label; so does stopping local dev
# servers (kill/pkill/agent-browser close), which hold nothing.
DISPOSABLE_RE='((^|/)(tmp|temp|scratch[^/]*|scratchpad|node_modules|\.next|\.turbo|\.cache|dist|build|out|coverage|__pycache__|\.pytest_cache|logs?|worktrees)(/|$)|^/private/tmp/|^/tmp/|/\.claude/jobs/[^/]+/tmp(/|$)|\.(log|tmp|bak[^/]*|pyc)$)'
if [ "$KIND" = "destructive_fs" ]; then
  rm_targets=$(printf '%s' "$CMD" | tr ';&|' '\n\n\n' | grep -E '^[[:space:]]*rm[[:space:]]' | sed -E 's/^[[:space:]]*rm[[:space:]]+//; s/(^|[[:space:]])-[a-zA-Z-]+//g' | tr ' ' '\n' | grep -vE '^$' | CWD="$CWD" python3 -c 'import os,sys
cwd=os.environ.get("CWD","/")
for l in sys.stdin:
    t=os.path.expanduser(l.strip().strip("\x27\x22"))
    if t: print(os.path.normpath(t if t.startswith("/") else os.path.join(cwd,t)))' 2>/dev/null)
  other_destructive=0; printf '%s' "$CMD" | grep -qE '(^|[;&|[:space:]])(rm|mv|dd|truncate|shred|git (clean|checkout -- |restore)|psql|mysql|gcloud [a-z ]*delete|aws [a-z0-9 -]*delete|DROP |DELETE FROM|TRUNCATE )' && other_destructive=1
  if [ -n "$rm_targets" ] && ! printf '%s\n' "$rm_targets" | grep -vqE "$DISPOSABLE_RE"; then
    rest=$(printf '%s' "$CMD" | tr ';&|' '\n\n\n' | grep -vE '^[[:space:]]*rm[[:space:]]')
    if ! printf '%s' "$rest" | grep -qE '(^|[;&|[:space:]])(mv|dd|truncate|shred|git (clean|restore)|psql|mysql|gcloud [a-z ]*delete|aws [a-z0-9 -]*delete)|DROP |DELETE FROM|TRUNCATE '; then KIND="benign"; why="scratch only"; fi
  elif [ "$other_destructive" = "0" ] && printf '%s' "$CMD" | grep -qE '(^|[;&|[:space:]])(kill|pkill|killall|agent-browser (close|stop)|lsof -ti)'; then
    KIND="benign"; why="stops local processes"
  fi
fi
if [ "$own_only" = "1" ]; then :
elif [ "$KIND" = "unknown_host" ]; then verdict=ask; why="$why (no secret read — asking)" 
elif ge "$P_RISKY" "$DENY_P" && [ "$KIND" != "benign" ]; then verdict=deny; why="p(risky)=$P_RISKY"
elif printf '%s' "$CMD" | grep -qE '(^|[;&|[:space:]])sudo[[:space:]]'; then verdict=ask; why="uses sudo"   # deterministic, never silently allowed
elif { [ "$KIND" = "exfiltration" ] || [ "$KIND" = "security_downgrade" ]; } && ge "$KIND_CONF" 0.8; then verdict=deny; why="confidently ${KIND//_/ }"
elif [ "$KIND" = "git_history" ] && ge "$KIND_CONF" 0.8 && lt "$P_ROUTINE" 0.5; then verdict=deny; why="rewrites shared history"
elif [ "$KIND" = "privilege" ] && ge "$KIND_CONF" 0.6; then verdict=ask; why="uses sudo / system config"
elif ge "$P_REMOTE" 0.6; then verdict=ask; why="downloads and runs remote code"
elif ge "$P_RISKY" "$ASK_P" && [ "$KIND" != "benign" ]; then verdict=ask; why="p(risky)=$P_RISKY"
elif [ "$KIND" = "destructive_fs" ] && ge "$KIND_CONF" 0.8 && lt "$P_DISP" 0.5 && lt "$P_ROUTINE" 0.6; then verdict=ask; why="deletes something that is not disposable"
elif [ "$KIND" = "git_history" ] && ge "$KIND_CONF" 0.6 && lt "$P_ROUTINE" 0.5; then verdict=ask; why="touches git history"
fi
printf '%s %-5s risky=%s routine=%s disp=%s remote=%s kind=%s(%s) branch=%s%s :: %s\n' "$(date '+%F %T')" "$verdict" "$P_RISKY" "$P_ROUTINE" "$P_DISP" "$P_REMOTE" "$KIND" "$KIND_CONF" "$BRANCH" "${why:+ [$why]}" "$MASKED" >> "$GLOG"
[ "$verdict" = "allow" ] && exit 0

REASON="jev-gate: ${why} — command classified as ${KIND//_/ } (branch ${BRANCH}). $( [ "$verdict" = "deny" ] && echo "Blocked. If it is really needed, explain to Harsha what it does and let him run it, or find a reversible way (dry-run, backup first, personal branch)." || echo "Asking Harsha before running it." )"
jq -n --arg d "$verdict" --arg r "$REASON" --arg s "jev-gate ${verdict}: ${why} — ${MASKED:0:80}" '{
  hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r },
  systemMessage: $s }'
exit 0
