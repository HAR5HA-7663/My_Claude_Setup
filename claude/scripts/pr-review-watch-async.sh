#!/usr/bin/env bash
# asyncRewake watcher for the PR review loop (see pr-review-bot.sh):
# bevri = Alex via @teli_review_bot, teli = Pranta on GitHub.
#
# Fires after `gh pr create` (bevri-ai PR URL in the output) and after
# `pr-review-bot request|rearm <url>` (a resubmission, or another watch window
# while Alex hasn't answered yet). Runs in the background and,
# when @teli_review_bot sends the PR back, exits 2 so the session that opened
# the PR is woken with the review and fixes it. Approval / timeout -> exit 0.
set -uo pipefail

IN=$(cat 2>/dev/null || true)
[ -z "$IN" ] && exit 0
CMD=$(echo "$IN" | jq -r '.tool_input.command // ""' 2>/dev/null || true)

if echo "$CMD" | grep -q 'gh pr create'; then
  URL=$(echo "$IN" | jq -r '.tool_response | tostring' 2>/dev/null \
        | grep -oE 'https://github\.com/[^/"]+/[^/"]+/pull/[0-9]+' | head -1)
# Only a command that IS the resubmit (not one that merely mentions it, e.g. a grep or a test).
elif echo "$CMD" | grep -qE '^[[:space:]]*(bash [^ ]*/)?pr-review-bot(\.sh)? (request|rearm) https://github\.com/[^ ]+/pull/[0-9]+[[:space:]]*$'; then
  URL=$(echo "$CMD" | grep -oE 'https://github\.com/[^/" ]+/[^/" ]+/pull/[0-9]+' | head -1)
else
  exit 0
fi
echo "${URL:-}" | grep -qE '^https://github\.com/(bevri-ai|teli-ai-llc)/' || exit 0

SID=$(echo "$IN" | jq -r '.session_id // ""' 2>/dev/null)
HCWD=$(echo "$IN" | jq -r '.cwd // ""' 2>/dev/null)
OUT=$(PR_SESSION_ID="$SID" PR_SESSION_CWD="$HCWD" bash "$HOME/.claude/scripts/pr-review-bot.sh" watch "$URL" 2>/dev/null)
RC=$?
if [ "$RC" -eq 2 ]; then
  # Keep the brief: if this chat is closed before it acts, pr-review-sweep.sh resumes it with this.
  # (Not for the hourly "still waiting" / "no verdict" hand-backs — nothing to act on there.)
  printf '%s' "$OUT" | head -1 | grep -qE 'still waiting on|^No verdict from' \
    || printf '%s' "$OUT" | bash "$HOME/.claude/scripts/pr-review-bot.sh" save-brief "$URL" >/dev/null 2>&1
  printf '%s\n' "$OUT"
  exit 2
fi
exit 0
