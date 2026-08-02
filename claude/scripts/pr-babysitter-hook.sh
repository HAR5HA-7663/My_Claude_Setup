#!/usr/bin/env bash
# PostToolUse launcher. When a `gh pr create` just ran:
#   1. Marks the PR ready-for-review if it was created as a draft.
#   2. Enables auto-merge on the PR (merge-commit first, falling back to
#      squash/rebase when the repo disallows a method).
#   3. Launches the PR babysitter in the background (base sync + checks watch).
#   4. Injects an instruction into the same session so the agent immediately
#      posts a Slack @channel approval request to channel C0BLMCYP95Y
#      (teliai.slack.com) via the Slack MCP.
# No-op for every other Bash command.
# Fed the hook JSON on stdin; matches on the command text + a PR URL in the output.
set -uo pipefail

IN=$(cat 2>/dev/null || true)
[ -z "$IN" ] && exit 0

CMD=$(echo "$IN" | jq -r '.tool_input.command // ""' 2>/dev/null || true)
echo "$CMD" | grep -q 'gh pr create' || exit 0

URL=$(echo "$IN" | jq -r '.tool_response | tostring' 2>/dev/null \
      | grep -oE 'https://github\.com/[^/"]+/[^/"]+/pull/[0-9]+' | head -1)
[ -z "$URL" ] && exit 0

OWNER_REPO=$(echo "$URL" | sed -E 's#https://github.com/([^/]+/[^/]+)/pull/[0-9]+.*#\1#')
PRNUM=$(echo "$URL" | sed -E 's#.*/pull/([0-9]+).*#\1#')
HLOG="$HOME/.claude/pr-babysitter-hook.log"

# --- draft -> ready-for-review ---
READY_NOTE="not a draft"
ISDRAFT=$(gh pr view "$PRNUM" --repo "$OWNER_REPO" --json isDraft --jq .isDraft 2>/dev/null || true)
if [ "$ISDRAFT" = "true" ]; then
  if gh pr ready "$PRNUM" --repo "$OWNER_REPO" >>"$HLOG" 2>&1; then
    READY_NOTE="draft marked ready-for-review"
  else
    READY_NOTE="draft but 'gh pr ready' FAILED (see pr-babysitter-hook.log)"
  fi
fi

# --- enable auto-merge (method fallback: merge -> squash -> rebase) ---
AM_NOTE="auto-merge enable FAILED (see pr-babysitter-hook.log)"
for m in --merge --squash --rebase; do
  if gh pr merge "$PRNUM" --repo "$OWNER_REPO" --auto "$m" >>"$HLOG" 2>&1; then
    AM_NOTE="auto-merge enabled (${m#--})"
    break
  fi
done
echo "$(date '+%Y-%m-%d %H:%M:%S') $OWNER_REPO#$PRNUM: $READY_NOTE; $AM_NOTE" >> "$HLOG"

# NOTE: the babysitter itself is NOT launched here any more. It runs as a
# separate asyncRewake hook (pr-babysitter-async.sh) so that a merge conflict
# can wake THIS session — the one that authored the PR and therefore knows what
# the change meant — instead of being resolved blind by a detached process.

SLACK_INSTR="A PR was just created: $URL ($OWNER_REPO #$PRNUM). Do this NOW, before continuing with anything else: send an approval request to Slack channel C0BLMCYP95Y (teliai.slack.com workspace) using the Slack MCP tools (load them via ToolSearch if not loaded).

MESSAGE FORMAT — follow exactly, these rules exist because past sends produced broken links:
1. Start with the literal token <!channel> (that is how @channel is written over the API so the whole group gets notified).
2. Wrap the PR URL in ANGLE BRACKETS: <$URL>. Slack's autolinker otherwise swallows whatever follows the bare URL into the href (a real bug we hit: 'pull/3394_this makes smp...' became one dead link). The angle brackets delimit it explicitly. Never paste the URL bare, and never put any character immediately after it.
3. The URL must be the LAST thing on its line. Any extra detail goes on a NEW line (real newline in the text field), never appended after the link on the same line.
4. Harsha's casual lowercase Slack voice; no bold/headers/bullets.

So the default shape is exactly:
<!channel> pr request $PRNUM please approve it <$URL>

If this PR touches something reviewers should specifically double-check (migration, auth, billing/Stripe, config, risky refactor), add ONE short lowercase line AFTER a newline saying what to check. Otherwise send just the one line above.

Send it as a real message, not a draft. Mechanical steps already done by the hook: $READY_NOTE; $AM_NOTE. If one of those FAILED, retry it once yourself ('gh pr ready $PRNUM --repo $OWNER_REPO' / 'gh pr merge $PRNUM --repo $OWNER_REPO --auto --merge'); if it still fails, just report the failure — NEVER merge the PR directly yourself."

jq -n --arg url "$URL" --arg ready "$READY_NOTE" --arg am "$AM_NOTE" --arg instr "$SLACK_INSTR" '{
  systemMessage: "PR babysitter launched for \($url) — \($ready); \($am); Slack @channel approval request handed to the agent; base-sync + checks watch running.",
  hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $instr}
}'
exit 0
