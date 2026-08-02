#!/usr/bin/env bash
# asyncRewake companion to pr-babysitter-hook.sh.
#
# Registered with `asyncRewake: true`, so it runs in the BACKGROUND (never
# blocking the turn) and, on exit code 2, wakes the very session that ran
# `gh pr create` and injects this script's stdout as a system-reminder.
#
# That is the whole point: when the PR hits a merge conflict, the session that
# authored the change resolves it — it knows what the code was meant to do.
# A freshly spawned agent would be reading the diff cold.
#
# Exit codes: 0 = nothing to do / PR healthy or failed for other reasons
#             2 = needs the session (merge conflict) -> rewake with stdout
set -uo pipefail

IN=$(cat 2>/dev/null || true)
[ -z "$IN" ] && exit 0

CMD=$(echo "$IN" | jq -r '.tool_input.command // ""' 2>/dev/null || true)
echo "$CMD" | grep -q 'gh pr create' || exit 0

URL=$(echo "$IN" | jq -r '.tool_response | tostring' 2>/dev/null \
      | grep -oE 'https://github\.com/[^/"]+/[^/"]+/pull/[0-9]+' | head -1)
[ -z "$URL" ] && exit 0

# Run the babysitter INLINE (not nohup'd) so its exit code is ours: the loop's
# `handback_conflict` exits 2 and prints the resolution brief on stdout, which
# is exactly what the rewake needs to carry back to the session.
OUT=$(bash "$HOME/.claude/scripts/pr-babysitter.sh" "$URL" 2>/dev/null)
RC=$?

if [ "$RC" -eq 2 ]; then
  printf '%s\n' "$OUT"
  exit 2
fi
exit 0
