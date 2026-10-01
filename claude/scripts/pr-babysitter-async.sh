#!/usr/bin/env bash
# asyncRewake companion to pr-babysitter-hook.sh.
#
# Registered with `asyncRewake: true`, so it runs in the BACKGROUND (never
# blocking the turn) and, on exit code 2, wakes the very session that ran
# `gh pr create` and injects this script's stdout as a system-reminder.
#
# That is the whole point: when the PR hits a merge conflict, or the reviewer
# (Alex via @teli_review_bot for bevri, Pranta on GitHub for teli) sends it back,
# the session that authored the change handles it — it knows what the code was
# meant to do. A freshly spawned agent would be reading the diff cold.
#
# Fires on:
#   gh pr create                                         -> base sync + checks, then review watch
#   bash ~/.claude/scripts/pr-babysitter.sh review request|rearm <url>
#                                                        -> next review watch window (resubmit / still waiting)
#
# Org gate (mirrors pr-babysitter-hook.sh): only bevri-ai and teli-ai-llc PRs.
# Any other org -> exit 0 immediately, nothing is set up.
#
# Exit codes: 0 = nothing to do / PR healthy / approved
#             2 = needs the session (conflict, review feedback, still-waiting re-arm) -> rewake with stdout
set -uo pipefail

IN=$(cat 2>/dev/null || true)
[ -z "$IN" ] && exit 0
SELF="$HOME/.claude/scripts/pr-babysitter.sh"

CMD=$(echo "$IN" | jq -r '.tool_input.command // ""' 2>/dev/null || true)
CREATED=0
if echo "$CMD" | grep -q 'gh pr create'; then
  CREATED=1
  URL=$(echo "$IN" | jq -r '.tool_response | tostring' 2>/dev/null \
        | grep -oE 'https://github\.com/[^/"]+/[^/"]+/pull/[0-9]+' | head -1)
# Only a command that IS the resubmit (not one that merely mentions it, e.g. a grep).
elif echo "$CMD" | grep -qE '^[[:space:]]*bash [^ ]*pr-babysitter\.sh review (request|rearm) https://github\.com/[^ ]+/pull/[0-9]+[[:space:]]*$'; then
  URL=$(echo "$CMD" | grep -oE 'https://github\.com/[^/" ]+/[^/" ]+/pull/[0-9]+' | head -1)
else
  exit 0
fi
[ -z "${URL:-}" ] && exit 0

OWNER=$(echo "$URL" | sed -E 's#https://github.com/([^/]+)/.*#\1#')
case "$OWNER" in
  bevri-ai|teli-ai-llc) ;;   # babysit
  *) exit 0 ;;               # anything else: no poller at all
esac

if [ "$CREATED" = "1" ]; then
  # Run the babysitter INLINE (not nohup'd) so its exit code is ours: the loop's
  # `handback_conflict` exits 2 and prints the resolution brief on stdout, which
  # is exactly what the rewake needs to carry back to the session.
  OUT=$(bash "$SELF" "$URL" 2>/dev/null)
  RC=$?
  if [ "$RC" -eq 2 ]; then
    printf '%s\n' "$OUT"
    exit 2
  fi
fi

# --- review watch: the rest of this hook's 3600 s budget ---
SID=$(echo "$IN" | jq -r '.session_id // ""' 2>/dev/null)
HCWD=$(echo "$IN" | jq -r '.cwd // ""' 2>/dev/null)
LEFT=$(( 3450 - SECONDS )); [ "$LEFT" -lt 300 ] && LEFT=300
OUT=$(WATCH_S="$LEFT" PR_SESSION_ID="$SID" PR_SESSION_CWD="$HCWD" bash "$SELF" review watch "$URL" 2>/dev/null)
RC=$?
if [ "$RC" -eq 2 ]; then
  # Keep the brief: if this chat is closed before it acts, `pr-babysitter.sh sweep` resumes it with this.
  # (Not for the hourly "still waiting" / "no verdict" hand-backs — nothing to act on there.)
  printf '%s' "$OUT" | head -1 | grep -qE 'still waiting on|^No verdict from' \
    || printf '%s' "$OUT" | bash "$SELF" review save-brief "$URL" >/dev/null 2>&1
  printf '%s\n' "$OUT"
  exit 2
fi
exit 0
