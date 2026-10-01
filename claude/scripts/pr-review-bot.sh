#!/usr/bin/env bash
# Review loop for bevri-ai PRs (added 2026-10-01). Replaces the Slack approval
# ping for bevri: the PR is sent to @teli_review_bot on Telegram (as Harsha, via
# the `tg` Telethon CLI). The bot is Alex's — it queues the PR for Alex, who
# reviews it by hand and answers back through the bot (and/or on GitHub as
# alexi089). His verdict is watched, and the session that opened the PR fixes
# what he asked for and sends it back. Human review = hours, so the watcher
# re-arms itself hourly (rewake -> `pr-review-bot rearm`) up to MAX_WAIT_H.
#
# teli-ai-llc PRs (added 2026-10-01) use the same loop without Telegram: Pranta
# (GitHub baruapra) reviews on GitHub — as review states AND as plain PR
# conversation comments ("re-review ... approval stands") — so the watcher reads
# reviews + issue comments + inline comments and wakes the PR's session on every
# round until he approves. No round cap for teli. (GitHub webhooks would need repo
# admin, which we don't have on teli-ai-llc, so this polls `gh api` once a minute.)
#
#   pr-review-bot request <pr-url>   send "PR <n> <repo>" to the bot (next round), or —
#                                    once MAX_BOT_ROUNDS rounds were sent back — print the
#                                    Slack escalation (tag Arbaaz) for the agent to send
#   pr-review-bot watch <pr-url>     poll the bot's Telegram replies + GitHub reviews;
#                                    exit 0 = approved / nothing to do,
#                                    exit 2 = changes requested (brief on stdout, for rewake)
#   pr-review-bot rearm <pr-url>     no-op marker: the async hook matches it and starts
#                                    another watch window for a PR still waiting on Alex
#   pr-review-bot status <pr-url>    print the PR's loop state
#   pr-review-bot save-brief <url>   (stdin) keep the last wake-up brief in state so the
#                                    sweeper (pr-review-sweep.sh) can resume a closed chat
#
#   ONESHOT=1 pr-review-bot watch <url>  one poll, no waiting: exit 2 + brief on a verdict,
#                                    exit 3 when there is nothing yet (used by the sweeper)
#
# State: ~/.claude/pr-review-bot/<repo>-<n>.json   Log: ~/.claude/pr-review-bot/loop.log
set -uo pipefail

BOT="@teli_review_bot"
MAX_BOT_ROUNDS=${MAX_BOT_ROUNDS:-3}      # bot rounds before escalating to a human
POLL_S=${POLL_S:-60}
WATCH_S=${WATCH_S:-3300}                 # one window; stays under the async hook's 3600 s timeout
MAX_WAIT_H=${MAX_WAIT_H:-12}             # stop re-arming after this long without a verdict
ME_GH="HAR5HA-7663"
SLACK_GROUP="C0BLMCYP95Y"                # bevri PR-request group DM (harsha + arbaaz + alex)
ARBAAZ_SLACK="U0BA70W0F1D"
TG="${TG_BIN:-$HOME/.local/bin/tg}"

DIR="${PR_REVIEW_BOT_DIR:-$HOME/.claude/pr-review-bot}"; mkdir -p "$DIR"
LOG="$DIR/loop.log"

CMD="${1:-}"; URL="${2:-}"
echo "$URL" | grep -qE '^https://github\.com/(bevri-ai|teli-ai-llc)/[^/]+/pull/[0-9]+' \
  || { echo "usage: pr-review-bot request|watch|rearm|status <bevri-ai|teli-ai-llc PR url>"; exit 1; }
OWNER=$(echo "$URL" | sed -E 's#https://github.com/([^/]+)/([^/]+)/pull/([0-9]+).*#\1#')
REPO=$(echo  "$URL" | sed -E 's#https://github.com/([^/]+)/([^/]+)/pull/([0-9]+).*#\2#')
PR=$(echo    "$URL" | sed -E 's#https://github.com/([^/]+)/([^/]+)/pull/([0-9]+).*#\3#')
URL="https://github.com/$OWNER/$REPO/pull/$PR"
if [ "$OWNER" = "teli-ai-llc" ]; then ORG=teli; WHO="Pranta"; MAX_WAIT_H=${MAX_WAIT_H_TELI:-24}
else ORG=bevri; WHO="Alex"; fi
STATE="$DIR/$OWNER-$REPO-$PR.json"
[ -f "$STATE" ] || [ "$CMD" = "request" ] || { echo "no review loop for $OWNER/$REPO#$PR"; exit 0; }
[ -f "$STATE" ] || jq -n --arg url "$URL" --arg repo "$REPO" --argjson pr "$PR" \
  '{url:$url, repo:$repo, pr:$pr, rounds:0, last_sent_id:0, sent_at:null, status:"new"}' > "$STATE"

log()  { echo "$(date '+%Y-%m-%d %H:%M:%S') $REPO#$PR $*" >> "$LOG"; }
get()  { jq -r "$1" "$STATE"; }
put()  { local t; t=$(mktemp "$DIR/.st.XXXX") && jq "$@" "$STATE" > "$t" && mv "$t" "$STATE"; }
notify() { osascript -e "display notification \"$2\" with title \"PR review bot · $REPO#$PR · $1\"" 2>/dev/null || true; }
# Telethon keeps its session in SQLite; two tg processes at once can hit "database is locked".
tgr() { local i out; for i in 1 2 3; do out=$("$TG" "$@" 2>&1) && { printf '%s' "$out"; return 0; }; sleep $((i * 3)); done; printf '%s' "$out" >&2; return 1; }

case "$CMD" in
status) cat "$STATE"; echo; exit 0 ;;

save-brief)
  B=$(cat); [ -n "$B" ] && put --arg b "$B" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.brief=$b | .brief_at=$at | .brief_pending=true'
  exit 0 ;;

rearm)
  [ "$(get .status)" = "waiting" ] || { echo "PR #$PR is '$(get .status)' — nothing to re-arm"; exit 0; }
  echo "still waiting on $WHO for PR #$PR (round $(get .rounds)) — watcher re-armed in the background"; exit 0 ;;

request)
  ROUNDS=$(get .rounds)
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  if [ "$ORG" = "teli" ]; then
    NEXT=$((ROUNDS + 1))
    # Feedback that landed while the session was fixing still counts: resume from when it was seen.
    put --arg at "$NOW" --argjson n "$NEXT" '.rounds=$n | .sent_at=(.since // $at) | del(.since) | .brief_pending=false | .status="waiting"'
    RR=""
    if [ "$NEXT" -gt 1 ]; then   # re-request review from whoever reviewed last -> GitHub notifies them
      LAST=$(gh api "repos/$OWNER/$REPO/pulls/$PR/reviews" --jq '[.[] | select(.user.type != "Bot" and .user.login != "'"$ME_GH"'")] | last | .user.login // empty' 2>/dev/null)
      [ -n "$LAST" ] && gh api -X POST "repos/$OWNER/$REPO/pulls/$PR/requested_reviewers" -f "reviewers[]=$LAST" >/dev/null 2>&1 && RR=" Re-requested review from $LAST."
    fi
    log "teli round $NEXT armed.$RR"
    echo "teli review round $NEXT armed for PR #$PR.$RR A background watcher wakes you on Pranta's next review or comment."
    exit 0
  fi
  if [ "$ROUNDS" -ge "$MAX_BOT_ROUNDS" ]; then
    put '.status="escalated"'
    log "escalate: bot sent it back $ROUNDS times -> Slack $SLACK_GROUP tagging Arbaaz"
    notify ESCALATE "bot sent it back $ROUNDS times — asking Arbaaz on Slack"
    cat <<EOF
ESCALATE — do NOT send this PR to the review bot again. Alex has sent it back $ROUNDS times through it.
Send this ONE Slack message now with the Slack MCP (slack_send_message, channel_id "$SLACK_GROUP"; load it via ToolSearch if needed), as a real message, not a draft:

<@$ARBAAZ_SLACK> pr request $PR alex sent it back $ROUNDS times through the review bot can you once review it and approve <$URL>

Rules: keep <@$ARBAAZ_SLACK> literally (that is the @mention), keep the URL in angle brackets as the LAST thing on the line, Harsha's lowercase voice, no bold/bullets. Send it only to $SLACK_GROUP.
EOF
    exit 0
  fi
  OUT=$(tgr send "$BOT" "PR $PR $REPO") || { log "tg send FAILED: $OUT"; echo "FAILED to message $BOT: $OUT"; exit 1; }
  MID=$(echo "$OUT" | sed -nE 's/^sent id=([0-9]+).*/\1/p')
  NEXT=$((ROUNDS + 1))
  put --argjson mid "${MID:-0}" --arg at "$NOW" --argjson n "$NEXT" \
      '.rounds=$n | .last_sent_id=$mid | .sent_at=$at | del(.since) | .brief_pending=false | .status="waiting"'
  log "round $NEXT/$MAX_BOT_ROUNDS sent to $BOT (tg msg $MID)"
  echo "sent 'PR $PR $REPO' to $BOT — review round $NEXT of $MAX_BOT_ROUNDS; a background watcher picks up the verdict."
  exit 0
  ;;

watch)
  # Remember which Claude Code chat owns this PR (the asyncRewake goes back to it; kept
  # in state so a later resume can target the same session).
  [ -n "${PR_SESSION_ID:-}" ] && put --arg sid "$PR_SESSION_ID" --arg cwd "${PR_SESSION_CWD:-}" \
    '.session_id=$sid | .cwd=$cwd | .sessions=((.sessions // []) + [$sid] | unique)'
  # The request may still be in flight (the sync hook and this watcher start together).
  [ "${ONESHOT:-0}" = "1" ] || for _ in $(seq 1 12); do [ "$(get .status)" = "waiting" ] && break; sleep 5; done
  [ "$(get .status)" = "waiting" ] || { log "watch: status=$(get .status), nothing to watch"; exit 0; }
  SENT_ID=$(get .last_sent_id); SENT_AT=$(get .sent_at); ROUND=$(get .rounds)
  # Bot replies about THIS PR: mentions the number, or nothing else is pending.
  OTHERS=$(jq -r 'select(.status=="waiting") | .pr' "$DIR"/*.json 2>/dev/null | grep -vx "$PR" | wc -l | tr -d ' ')
  log "watch: round $ROUND, after tg msg $SENT_ID / $SENT_AT"
  DEADLINE=$(( $(date +%s) + WATCH_S ))
  [ "${ONESHOT:-0}" = "1" ] && { DEADLINE=$(( $(date +%s) + 1 )); POLL_S=0; }

  while [ "$(date +%s)" -lt "$DEADLINE" ]; do
    sleep "$POLL_S"
    [ "${ONESHOT:-0}" = "1" ] || put --argjson t "$(date +%s)" '.heartbeat=$t'   # sweeper: a live watcher owns this PR
    [ "$(get .status)" = "waiting" ] && [ "$(get .sent_at)" = "$SENT_AT" ] && [ "$(get .rounds)" = "$ROUND" ] \
      || { log "watch: superseded (status=$(get .status)) — stopping"; exit 0; }

    BOTTXT=""
    [ "$ORG" = "bevri" ] && BOTTXT=$(tgr json "$BOT" 30 2>/dev/null | jq -r --argjson sid "$SENT_ID" --arg pr "$PR" --argjson others "$OTHERS" '
      [ .[] | select(.out == false and .id > $sid)
            | select($others == 0 or (.text | test("(PR|#|pull/) ?" + $pr + "\\b"; "i"))) | .text ]
      | join("\n---\n")' 2>/dev/null)
    GHREV=$(gh api "repos/$OWNER/$REPO/pulls/$PR/reviews" 2>/dev/null | jq -r --arg at "$SENT_AT" --arg me "$ME_GH" '
      [ .[] | select(.submitted_at > $at and .user.login != $me and .user.type != "Bot" and .state != "DISMISSED") ]')
    # PR conversation comments (Pranta posts re-reviews there) — humans only, not us.
    ISSUEC=""
    [ "$ORG" = "teli" ] && ISSUEC=$(gh api "repos/$OWNER/$REPO/issues/$PR/comments" 2>/dev/null | jq -r --arg at "$SENT_AT" --arg me "$ME_GH" '
      [ .[] | select(.created_at > $at and .user.login != $me and .user.type != "Bot") | "\(.user.login): \(.body)" ] | join("\n---\n")' 2>/dev/null)
    INLINE=$(gh api "repos/$OWNER/$REPO/pulls/$PR/comments" 2>/dev/null | jq -r --arg at "$SENT_AT" --arg me "$ME_GH" '
      .[] | select(.created_at > $at and .user.login != $me and .user.type != "Bot") | "- \(.path):\(.line // .original_line // "?") — \(.body)"' 2>/dev/null)
    GHSTATE=$(printf '%s' "$GHREV" | jq -r 'map(.state) | if index("CHANGES_REQUESTED") then "CHANGES_REQUESTED" elif index("APPROVED") then "APPROVED" else "" end' 2>/dev/null)

    VERDICT=""
    if [ "$GHSTATE" = "APPROVED" ]; then VERDICT=approved
    elif [ "$GHSTATE" = "CHANGES_REQUESTED" ]; then VERDICT=changes
    elif [ "$ORG" = "teli" ]; then
      # Review left as COMMENTED, or a conversation comment / inline comments with no review state.
      FEED="$(printf '%s' "$GHREV" | jq -r '.[].body' 2>/dev/null)$ISSUEC$INLINE"
      if [ -n "$FEED" ]; then
        if echo "$FEED" | grep -qiE 'request(ed|ing)? changes|changes requested|blocking|blocker|must fix'; then VERDICT=changes
        elif echo "$FEED" | grep -qiE 'approval stands|verdict: *approve|\bapproved?\b|lgtm'; then VERDICT=approved
        else VERDICT=changes; fi   # any other human feedback = something to address
      fi
    elif [ -n "$BOTTXT" ]; then
      if   echo "$BOTTXT" | grep -qiE "changes requested|request(ed|ing)? changes|needs? (changes|work)|blocking|blocker|must fix|not approv|can'?t approve|cannot approve|reject"; then VERDICT=changes
      elif echo "$BOTTXT" | grep -qiE '\b(approved|approving|lgtm)\b'; then VERDICT=approved
      elif [ "${#BOTTXT}" -gt 250 ]; then VERDICT=unclear   # a real review we can't classify — let the session judge
      fi                                                  # short unclassified = queue ack, keep waiting
    fi
    [ -z "$VERDICT" ] && continue

    if [ "$VERDICT" = "approved" ]; then
      put '.status="approved"'; log "watch: APPROVED in round $ROUND"
      notify APPROVED "$WHO approved it (round $ROUND)"
      if [ "$ORG" = "teli" ]; then
        # Pranta's approvals often carry nits — hand them over once; the loop itself ends here.
        cat <<EOF
Pranta APPROVED PR #$PR ($OWNER/$REPO) in review round $ROUND. The review loop is finished — do not re-request review.

His approval / comments:
$(printf '%s' "$GHREV" | jq -r '.[] | "[\(.state)] \(.user.login): \(.body)"' 2>/dev/null)
$ISSUEC
${INLINE:+
Inline comments:
$INLINE}

If the approval lists nits or follow-ups, address them on the PR branch, push, and post one PR comment (gh pr comment) saying which items are closed in which commit — same style as earlier rounds. If it is a clean approval, just tell Harsha it's approved. Never merge it yourself.
EOF
        exit 2
      fi
      exit 0
    fi

    put --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.status="changes_requested" | .since=$at'; log "watch: $VERDICT in round $ROUND"
    notify CHANGES "$WHO sent it back (round $ROUND) — waking the PR's session"
    if [ "$ORG" = "teli" ]; then
      cat <<EOF
Pranta reviewed PR #$PR ($OWNER/$REPO) — review round $ROUND — and has NOT approved it yet.

GitHub reviews since round $ROUND started:
$(printf '%s' "$GHREV" | jq -r '.[] | "[\(.state)] \(.user.login): \(.body)"' 2>/dev/null)
${ISSUEC:+
PR conversation comments:
$ISSUEC}
${INLINE:+
Inline comments:
$INLINE}

You opened this PR, so you have the context. Do this now, before other work:
1. Address every point on the PR's own branch (the worktree/branch you opened it from). If a requested change is wrong, unsafe, or needs a product decision, stop and ask Harsha instead of guessing.
2. Commit and push to the PR branch (never force-push a shared branch); merge origin/main in if it is behind.
3. Post ONE PR comment with gh pr comment, same style as earlier rounds: "Round $ROUND addressed in \`<sha>\`" then each item number and what changed (tests run + result).
4. Then run:  pr-review-bot request $URL
   That re-requests Pranta's review on GitHub and starts the next watcher. This repeats until he approves.
EOF
      exit 2
    fi
    LEFT=$((MAX_BOT_ROUNDS - ROUND))
    cat <<EOF
Alex reviewed PR #$PR ($OWNER/$REPO) via @teli_review_bot — round $ROUND of $MAX_BOT_ROUNDS — and did NOT approve it.$( [ "$VERDICT" = "unclear" ] && echo " (Verdict could not be classified automatically — read it and judge: if it is actually an approval, do nothing and say so.)" )

Alex's reply through the bot (Telegram):
${BOTTXT:-<none — the verdict came from GitHub>}

GitHub reviews since the request:
$(printf '%s' "$GHREV" | jq -r '.[] | "[\(.state)] \(.user.login): \(.body)"' 2>/dev/null)
${INLINE:+
Inline comments:
$INLINE}

You opened this PR, so you have the context. Do this now, before other work:
1. Address every point on the PR's own branch (the worktree/branch you opened it from). Fix what Alex asked for; do not reply to him through the bot.
   If a requested change is wrong, unsafe, or needs a product decision, stop and ask Harsha instead of guessing.
2. Commit and push to the PR branch (never force-push a shared branch).
3. Then run:  pr-review-bot request $URL
   $( [ "$LEFT" -gt 0 ] && echo "That sends it back to the bot ($LEFT bot round(s) left) and starts a new watcher." || echo "Bot rounds are used up — that command prints the Slack escalation (tag Arbaaz in the PR group); send it exactly as printed." )
EOF
    exit 2
  done
  WAITED_H=$(( ( $(date +%s) - $(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$SENT_AT" +%s 2>/dev/null || date +%s) ) / 3600 ))
  if [ "$WAITED_H" -ge "$MAX_WAIT_H" ] && [ "${ONESHOT:-0}" = "1" ]; then
    put '.status="stalled"'; log "sweep: no verdict after ${WAITED_H}h — giving up"
    notify STALLED "no verdict from $WHO after ${WAITED_H}h — nudge him yourself"; exit 3
  fi
  [ "${ONESHOT:-0}" = "1" ] && exit 3
  if [ "$WAITED_H" -ge "$MAX_WAIT_H" ]; then
    put '.status="stalled"'; log "watch: no verdict after ${WAITED_H}h — giving up"
    notify STALLED "no verdict from $WHO after ${WAITED_H}h — nudge him yourself"
    echo "No verdict from $WHO on PR #$PR after ${WAITED_H}h (round $ROUND). Stop watching; tell Harsha it is still waiting on $WHO so he can nudge him. Do not message $WHO or the bot yourself."
    exit 2
  fi
  log "watch: no verdict yet after ${WAITED_H}h — handing back for re-arm"
  echo "PR #$PR is still waiting on $WHO's review (${WAITED_H}h so far, round $ROUND). Nothing to fix. Run exactly:  pr-review-bot rearm $URL  — then carry on with whatever you were doing."
  exit 2
  ;;

*) echo "usage: pr-review-bot request|watch|rearm|status <bevri-ai|teli-ai-llc PR url>"; exit 1 ;;
esac
