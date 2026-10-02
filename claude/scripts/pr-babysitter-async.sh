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
# Whole body in one brace group: parsed before it runs, so edits to this file can't
# corrupt a hook that is already running (replace the file atomically anyway).
{

IN=$(cat 2>/dev/null || true)
[ -z "$IN" ] && exit 0
SELF="$HOME/.claude/scripts/pr-babysitter.sh"

CMD=$(echo "$IN" | jq -r '.tool_input.command // ""' 2>/dev/null || true)
SID=$(echo "$IN" | jq -r '.session_id // ""' 2>/dev/null)

# --- deliver a review this chat never got (its watcher was down when the reviewer answered).
# Runs on ANY Bash command of the owning chat, so a busy chat picks it up on its next command.
if [ -n "$SID" ]; then
  for f in "$HOME"/.claude/pr-babysitter/*.json; do
    [ -f "$f" ] || continue
    jq -e --arg s "$SID" '.session_id == $s and .brief_pending == true and (.delivered_to // "") != $s and .status != "waiting"' "$f" >/dev/null 2>&1 || continue
    t=$(mktemp "$f.XXXX") && jq --arg s "$SID" '.delivered_to = $s' "$f" > "$t" && mv "$t" "$f"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $(jq -r '"\(.repo)#\(.pr)"' "$f") delivered saved review brief to chat $SID" >> "$HOME/.claude/pr-babysitter/loop.log"
    jq -r .brief "$f"; exit 2
  done
fi

CREATED=0
# Only a real `gh pr create` invocation, never a command that merely mentions it (see the sync hook).
if printf '%s\n' "$CMD" | grep -qE '(^|[;&|(]|\$\(|&&|\|\|)[[:space:]]*(command[[:space:]]+)?gh[[:space:]]+pr[[:space:]]+create\b'; then
  CREATED=1
  URL=$(echo "$IN" | jq -r '.tool_response | tostring' 2>/dev/null \
        | grep -oE 'https://github\.com/[^/"]+/[^/"]+/pull/[0-9]+' | head -1)
# Only a command that IS the resubmit (not one that merely mentions it, e.g. a grep).
elif echo "$CMD" | grep -qE '^[[:space:]]*bash [^ ]*pr-babysitter\.sh review (request|rearm) https://github\.com/[^ ]+/pull/[0-9]+([[:space:]]+2>&1)?([[:space:]]*\|[[:space:]]*(tail|head)([[:space:]]+-n)?([[:space:]]+-?[0-9]+)?)?[[:space:]]*$'; then
  # A resubmit means new commits were pushed: restart the whole babysitter (base sync + checks) too.
  echo "$CMD" | grep -q ' review request ' && CREATED=1
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

HCWD=$(echo "$IN" | jq -r '.cwd // ""' 2>/dev/null)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/pr-babysitter.XXXX"); # No kill on exit: the checks watch finishes on its own (<= 20 min) and must clean up its own lock.
trap 'rm -rf "$TMP"' EXIT

# Base sync/checks (new PR or resubmit) and the review watch run SIDE BY SIDE: a reviewer can answer
# minutes after the PR opens, long before the up-to-20-min checks watch ends (missed #2649 that way).
if [ "$CREATED" = "1" ]; then
  # babysitter's `handback_conflict` exits 2 with the resolution brief on stdout
  ( bash "$SELF" "$URL" > "$TMP/sync.out" 2>/dev/null; echo $? > "$TMP/sync.rc" ) &
else
  echo 0 > "$TMP/sync.rc"
fi
( WATCH_S=3400 PR_SESSION_ID="$SID" PR_SESSION_CWD="$HCWD" bash "$SELF" review watch "$URL" > "$TMP/rev.out" 2>/dev/null
  echo $? > "$TMP/rev.rc" ) &

while :; do
  if [ "$(cat "$TMP/sync.rc" 2>/dev/null)" = "2" ]; then cat "$TMP/sync.out"; exit 2; fi
  if [ "$(cat "$TMP/rev.rc" 2>/dev/null)" = "2" ]; then
    OUT=$(cat "$TMP/rev.out")
    # Keep the brief: if this chat is closed before it acts, `pr-babysitter.sh sweep` resumes it with this.
    # (Not for the hourly "still waiting" / "no verdict" hand-backs — nothing to act on there.)
    printf '%s' "$OUT" | head -1 | grep -qE 'still waiting on|^No verdict from' \
      || printf '%s' "$OUT" | DELIVERED_TO="$SID" bash "$SELF" review save-brief "$URL" >/dev/null 2>&1
    printf '%s\n' "$OUT"; exit 2
  fi
  [ -f "$TMP/sync.rc" ] && [ -f "$TMP/rev.rc" ] && break   # both finished without needing the session
  sleep 5
done
exit 0
}
