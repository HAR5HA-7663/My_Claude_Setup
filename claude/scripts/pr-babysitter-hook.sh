#!/usr/bin/env bash
# PostToolUse launcher. When a `gh pr create` just ran, routes by GitHub org:
#
#   bevri-ai     -> ready-for-review + auto-merge + Slack @channel approval
#                   request to the bevri PR-request group DM (C0BLMCYP95Y:
#                   harsha + arbaaz + alex, teliai.slack.com) + babysitter.
#   teli-ai-llc  -> ready-for-review + auto-merge + Slack DM approval request
#                   to Pranta (U09HBRLNHK2) + babysitter.
#   anything else -> hard no-op: no ready, no auto-merge, no Slack, no poller
#                   (pr-babysitter-async.sh applies the same gate).
#
# The Slack send itself is done by the agent in the same session (instruction
# injected via additionalContext) using the Slack MCP.
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
OWNER=${OWNER_REPO%%/*}
PRNUM=$(echo "$URL" | sed -E 's#.*/pull/([0-9]+).*#\1#')
HLOG="$HOME/.claude/pr-babysitter-hook.log"

# --- org routing: who gets the approval request ---
case "$OWNER" in
  bevri-ai)
    ROUTE="bevri"
    TARGET_ID="C0BLMCYP95Y"
    TARGET_DESC="the bevri PR-request group DM (channel id C0BLMCYP95Y — harsha + arbaaz + alex, teliai.slack.com workspace)"
    MSG_SHAPE="<!channel> pr request $PRNUM please approve it <$URL>"
    MSG_RULE="Start with the literal token <!channel> (that is how @channel is written over the API so the whole group gets notified)."
    ;;
  teli-ai-llc)
    ROUTE="teli"
    TARGET_ID="U09HBRLNHK2"
    TARGET_DESC="Pranta (Pranta Nir Barua, Slack user id U09HBRLNHK2, teliai.slack.com) as a DIRECT MESSAGE — pass his user id U09HBRLNHK2 as the channel_id of slack_send_message, that opens the DM"
    MSG_SHAPE="hey pranta pr request $PRNUM please approve it <$URL>"
    MSG_RULE="This is a 1:1 DM to Pranta — do NOT use <!channel> or <!here>; just address him by name."
    ;;
  *)
    echo "$(date '+%Y-%m-%d %H:%M:%S') $OWNER_REPO#$PRNUM: org '$OWNER' is neither bevri-ai nor teli-ai-llc — skipped entirely (no ready/auto-merge/slack/poller)" >> "$HLOG"
    exit 0
    ;;
esac

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

# --- Jev risk pre-filter (added 2026-09-21): shared billing / schema / auth / deploy config ---
# A flagged PR is still marked ready and announced, but auto-merge is NOT armed: it waits for a
# human approval instead of merging the moment checks pass. Fail-open: if the classifier
# cannot run, behaviour is exactly as before.
RISK_JSON=$(bash "$HOME/.claude/scripts/jev-pr-risk.sh" "$OWNER_REPO" "$PRNUM" 2>/dev/null || echo '{"risky":null}')
RISKY=$(printf '%s' "$RISK_JSON" | jq -r '.risky' 2>/dev/null || echo null)
RISK_FLAGS=$(printf '%s' "$RISK_JSON" | jq -r '(.flags // []) | join("; ")' 2>/dev/null)
RISK_NOTE="jev-risk: $( [ "$RISKY" = "true" ] && echo "FLAGGED — $RISK_FLAGS" || { [ "$RISKY" = "false" ] && echo "clean ($(printf '%s' "$RISK_JSON" | jq -r '.scored // 0') files scored)" || echo "unavailable"; } )"

# --- enable auto-merge (method fallback: merge -> squash -> rebase) — unless the PR is flagged ---
if [ "$RISKY" = "true" ]; then
  AM_NOTE="auto-merge NOT armed (jev-risk flagged: $RISK_FLAGS) — merge only after a human approves"
else
  AM_NOTE="auto-merge enable FAILED (see pr-babysitter-hook.log)"
  for m in --merge --squash --rebase; do
    if gh pr merge "$PRNUM" --repo "$OWNER_REPO" --auto "$m" >>"$HLOG" 2>&1; then
      AM_NOTE="auto-merge enabled (${m#--})"
      break
    fi
  done
fi
echo "$(date '+%Y-%m-%d %H:%M:%S') $OWNER_REPO#$PRNUM: route=$ROUTE; $READY_NOTE; $AM_NOTE; $RISK_NOTE" >> "$HLOG"

# NOTE: the babysitter itself is NOT launched here. It runs as a separate
# asyncRewake hook (pr-babysitter-async.sh, same org gate) so that a merge
# conflict can wake THIS session — the one that authored the PR and therefore
# knows what the change meant — instead of being resolved blind by a detached
# process.

SLACK_INSTR="A PR was just created: $URL ($OWNER_REPO #$PRNUM). This is a $ROUTE PR. Do this NOW, before continuing with anything else: send an approval request to $TARGET_DESC using the Slack MCP tools (slack_send_message with channel_id \"$TARGET_ID\"; load the tool via ToolSearch if not loaded).

MESSAGE FORMAT — follow exactly, these rules exist because past sends produced broken links:
1. $MSG_RULE
2. Wrap the PR URL in ANGLE BRACKETS: <$URL>. Slack's autolinker otherwise swallows whatever follows the bare URL into the href (a real bug we hit: 'pull/3394_this makes smp...' became one dead link). The angle brackets delimit it explicitly. Never paste the URL bare, and never put any character immediately after it.
3. The URL must be the LAST thing on its line. Any extra detail goes on a NEW line (real newline in the text field), never appended after the link on the same line.
4. Harsha's casual lowercase Slack voice; no bold/headers/bullets.

So the default shape is exactly:
$MSG_SHAPE

$( if [ "$RISKY" = "true" ]; then echo "The Jev risk classifier flagged this PR: $RISK_FLAGS. Auto-merge was deliberately NOT armed, so add ONE short lowercase line AFTER a newline telling the reviewer exactly that (what to double-check, and that it needs a manual merge after approval). Do not arm auto-merge yourself."; else echo "If this PR touches something reviewers should specifically double-check (migration, auth, billing/Stripe, config, risky refactor), add ONE short lowercase line AFTER a newline saying what to check. Otherwise send just the one line above."; fi )

Send it as a real message, not a draft, and ONLY to $TARGET_ID — do not also post it anywhere else. Mechanical steps already done by the hook: $READY_NOTE; $AM_NOTE. If one of those FAILED, retry it once yourself ('gh pr ready $PRNUM --repo $OWNER_REPO' / 'gh pr merge $PRNUM --repo $OWNER_REPO --auto --merge'); if it still fails, just report the failure — NEVER merge the PR directly yourself."

jq -n --arg url "$URL" --arg route "$ROUTE" --arg target "$TARGET_ID" --arg ready "$READY_NOTE" --arg am "$AM_NOTE" --arg risk "$RISK_NOTE" --arg instr "$SLACK_INSTR" '{
  systemMessage: "PR babysitter launched for \($url) [\($route)] — \($ready); \($am); \($risk); Slack approval request (-> \($target)) handed to the agent; base-sync + checks watch running.",
  hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $instr}
}'
exit 0
