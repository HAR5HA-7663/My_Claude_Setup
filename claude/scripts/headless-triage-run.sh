#!/bin/bash
# headless-triage-run.sh morning|monday — run a triage skill in a headless Claude session.
#
# Same shape as ~/brain/scripts/daily_session_sync.sh: read-only MCP tools only (no Slack
# send, no Monday writes), a hard wall-clock cap, one attempt, logs + a notification.
# Scheduled by launchd (com.harsha.morning-triage daily 08:30, com.harsha.monday-triage
# Mondays 08:00). Run by hand:  bash headless-triage-run.sh morning
set -uo pipefail
KIND="${1:?morning|monday}"
CLAUDE_BIN="$HOME/.local/bin/claude"; [ -x "$CLAUDE_BIN" ] || CLAUDE_BIN="$(command -v claude)"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
STATE="$HOME/.local/state/jev"; mkdir -p "$STATE"
LOG="$STATE/headless-$KIND.log"
MODEL="${MODEL:-sonnet}"; TIMEOUT="${TIMEOUT:-1500}"   # 25 min cap
log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

READ_TOOLS="Read,Write,Glob,Grep,Bash,ToolSearch"
case "$KIND" in
  morning)
    OUT_DIR="$HOME/Desktop/morning-triage"; mkdir -p "$OUT_DIR"
    TOOLS="$READ_TOOLS,mcp__plugin_slack_slack__slack_list_user_channels,mcp__plugin_slack_slack__slack_read_channel,mcp__plugin_slack_slack__slack_read_thread,mcp__plugin_slack_slack__slack_search_public_and_private,mcp__plugin_slack_slack__slack_read_user_profile,mcp__plugin_slack_slack__slack_search_users,mcp__gmessages__list_conversations,mcp__gmessages__get_messages,mcp__gmessages__get_conversation,mcp__gmessages__list_contacts,mcp__gmessages__search_messages"
    PROMPT="Run the morning-triage skill (read ~/.claude/skills/morning-triage/SKILL.md and follow it exactly). Today is $(date '+%Y-%m-%d'). Window: since $(date -v-14H '+%Y-%m-%d %H:%M') unless a newer digest exists in $OUT_DIR. You are running headless: do not ask questions, never send or post anything, write the digest to $OUT_DIR/$(date '+%Y-%m-%d').md and finish. If a tool is missing, note it in the digest header and continue with what you have."
    ;;
  monday)
    OUT_DIR="$HOME/Desktop/monday-triage"; mkdir -p "$OUT_DIR"
    TOOLS="$READ_TOOLS,mcp__monday__search,mcp__monday__get_board_info,mcp__monday__get_board_items_page,mcp__monday__get_updates,mcp__monday__list_workspaces,mcp__monday__workspace_info,mcp__monday__all_api_read"
    PROMPT="Run the monday-triage skill (read ~/.claude/skills/monday-triage/SKILL.md and follow it exactly) on the BMYT board. Today is $(date '+%Y-%m-%d'). You are running headless: do not ask questions, post nothing to Monday, write the report to $OUT_DIR/$(date '+%Y-%m-%d').md and finish."
    ;;
  *) echo "usage: $0 morning|monday"; exit 2 ;;
esac

log "START $KIND (model=$MODEL)"
START=$(date +%s)
printf '%s' "$PROMPT" | "$CLAUDE_BIN" -p --model "$MODEL" --allowedTools "$TOOLS" >> "$LOG" 2>&1 &
PID=$!; WAITED=0
while kill -0 "$PID" 2>/dev/null; do
  if [ "$WAITED" -ge "$TIMEOUT" ]; then kill -TERM "$PID" 2>/dev/null; sleep 5; kill -KILL "$PID" 2>/dev/null; wait "$PID" 2>/dev/null; RC=124; break; fi
  sleep 10; WAITED=$((WAITED + 10))
done
[ "${RC:-}" ] || { wait "$PID"; RC=$?; }
ELAPSED=$(( $(date +%s) - START ))
DIGEST="$OUT_DIR/$(date '+%Y-%m-%d').md"
if [ "$RC" -eq 0 ] && [ -s "$DIGEST" ]; then
  HEAD=$(sed -n '3p' "$DIGEST" | cut -c1-120)
  log "DONE ok in ${ELAPSED}s -> $DIGEST"
  osascript -e "display notification \"${HEAD:-digest ready}\" with title \"$KIND triage ✅\"" 2>/dev/null || true
else
  log "FAIL rc=$RC after ${ELAPSED}s (digest present: $([ -s "$DIGEST" ] && echo yes || echo no))"
  osascript -e "display notification \"rc=$RC — see $LOG\" with title \"$KIND triage ❌\"" 2>/dev/null || true
fi
# bounded log
[ "$(wc -l < "$LOG")" -gt 6000 ] && { tail -n 4000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"; }
exit "$RC"
