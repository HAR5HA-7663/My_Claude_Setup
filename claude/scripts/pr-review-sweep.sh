#!/usr/bin/env bash
# PR review sweeper (launchd com.harsha.pr-review-sweep, every 5 min; added 2026-10-01).
#
# The review loop (pr-review-bot.sh) normally runs inside the Claude Code chat that
# opened the PR: its asyncRewake watcher wakes that chat when Alex / Pranta answer.
# If that chat is gone (closed, crashed, not in `claude agents`), the watcher died
# with it. This sweeper covers that gap:
#
#   - waiting PR, watcher heartbeat stale  -> one poll (ONESHOT watch). Verdict found ->
#                                             resume the owning chat in the background.
#   - brief_pending PR (wake-up produced but the chat is gone) -> resume with that brief.
#
# Resume = `claude --bg --resume <session-id> "<brief>"` in the session's cwd, so the
# fix happens in the chat that has the PR's context and shows up in `claude agents`.
# A chat that is still alive is never resumed (that would fork a copy): if its watcher
# died, Harsha gets a desktop notification instead, at most every REDISPATCH_S.
#
#   pr-review-sweep.sh            run once (what launchd does)
#   DRY_RUN=1 pr-review-sweep.sh  print what it would do
set -uo pipefail
export PATH="$PATH:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin"

DIR="${PR_REVIEW_BOT_DIR:-$HOME/.claude/pr-review-bot}"
LOG="$DIR/sweep.log"
BOTSH="$HOME/.claude/scripts/pr-review-bot.sh"
CLAUDE_BIN="${CLAUDE_BIN:-$HOME/.local/bin/claude}"; [ -x "$CLAUDE_BIN" ] || CLAUDE_BIN="$(command -v claude)"
STALE_S=${STALE_S:-300}          # watcher polls every 60 s; 5 min without a heartbeat = dead
REDISPATCH_S=${REDISPATCH_S:-1800}
DRY=${DRY_RUN:-0}
mkdir -p "$DIR"
[ -f "$LOG" ] && [ "$(wc -l < "$LOG")" -gt 5000 ] && { tail -n 2000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"; }

# Single instance — mkdir is atomic.
LOCK="$DIR/.sweep.lock.d"
if ! mkdir "$LOCK" 2>/dev/null; then
  [ -n "$(find "$LOCK" -maxdepth 0 -mmin +20 2>/dev/null)" ] && rmdir "$LOCK" 2>/dev/null && mkdir "$LOCK" 2>/dev/null || exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; [ "$DRY" = "1" ] && echo "$*"; }
notify() { osascript -e "display notification \"$2\" with title \"PR review sweep · $1\"" 2>/dev/null || true; }
upd() { local f="$1"; shift; local t; t=$(mktemp "$DIR/.sw.XXXX") && jq "$@" "$f" > "$t" && mv "$t" "$f"; }

shopt -s nullglob
FILES=("$DIR"/*.json)
[ ${#FILES[@]} -eq 0 ] && exit 0

AGENTS=$("$CLAUDE_BIN" agents --json 2>/dev/null || echo '[]')
NOW=$(date +%s)

dispatch() {   # <state-file> <brief>
  local f="$1" brief="$2" url sid cwd kind last out
  url=$(jq -r .url "$f"); sid=$(jq -r '.session_id // ""' "$f"); cwd=$(jq -r '.cwd // ""' "$f")
  if [ -z "$sid" ]; then
    log "$url: verdict but no session recorded — notifying only"
    notify "${url##*/pull/}" "review feedback on $url — no chat recorded, open it yourself"
    upd "$f" '.brief_pending=false'; return
  fi
  last=$(jq -r '.resumed_epoch // 0' "$f")
  [ $((NOW - last)) -lt "$REDISPATCH_S" ] && { log "$url: resumed $((NOW - last))s ago — not again yet"; return; }
  kind=$(printf '%s' "$AGENTS" | jq -r --arg s "$sid" '[.[] | select(.sessionId == $s)][0].kind // ""')
  if [ -n "$kind" ]; then
    # Alive but its watcher is gone, so it never got this. Resuming would fork a copy of a
    # live chat — tell Harsha instead; the brief stays pending for when that chat closes.
    log "$url: owning chat $sid is alive ($kind) but not watching — notify"
    notify "${url##*/pull/}" "review feedback on $url — chat $sid isn't watching; tell it: pr-review-bot rearm $url"
    upd "$f" --argjson t "$NOW" '.resumed_epoch=$t'; return
  fi
  [ -d "$cwd" ] || cwd="$HOME"
  local prompt="[pr-review-sweep] This chat was closed when the review came back on $url, so it was resumed in the background to handle it. Act on it exactly as instructed below, then finish.

$brief"
  if [ "$DRY" = "1" ]; then log "DRY: would resume $sid in $cwd for $url"; return; fi
  # No extra flags: with any flag `claude --bg --resume` starts a COPY instead of continuing
  # the same session (verified 10-01). The session keeps its own saved permission mode.
  out=$(cd "$cwd" && CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1 "$CLAUDE_BIN" --bg --resume "$sid" "$prompt" 2>&1 | tail -5)
  log "$url: resumed $sid in background ($cwd): $(echo "$out" | tr '\n' ' ' | cut -c1-200)"
  notify "${url##*/pull/}" "review feedback on $url — resumed its chat in claude agents"
  upd "$f" --argjson t "$NOW" '.brief_pending=false | .resumed_epoch=$t'
}

DISPATCHED=0
for f in "${FILES[@]}"; do
  [ "$DISPATCHED" -ge 1 ] && break     # one resume per sweep — RAM on a 16 GB machine
  st=$(jq -r .status "$f"); url=$(jq -r .url "$f")
  if [ "$(jq -r '.brief_pending // false' "$f")" = "true" ]; then
    hb=$(jq -r '.heartbeat // 0' "$f")
    sid=$(jq -r '.session_id // ""' "$f")
    alive=$(printf '%s' "$AGENTS" | jq -r --arg s "$sid" 'any(.[]; .sessionId == $s)')
    if [ "$alive" != "true" ]; then dispatch "$f" "$(jq -r .brief "$f")"; DISPATCHED=1
    elif [ $((NOW - hb)) -lt "$STALE_S" ] || [ "$st" != "waiting" ]; then :   # chat alive and was rewoken / is working on it
    fi
    continue
  fi
  [ "$st" = "waiting" ] || continue
  hb=$(jq -r '.heartbeat // 0' "$f")
  [ $((NOW - hb)) -lt "$STALE_S" ] && continue          # a live watcher owns it
  OUT=$(ONESHOT=1 bash "$BOTSH" watch "$url" 2>/dev/null); RC=$?
  if [ "$RC" -eq 2 ]; then
    log "$url: verdict found by sweep (watcher was gone)"
    printf '%s' "$OUT" | bash "$BOTSH" save-brief "$url" >/dev/null 2>&1
    dispatch "$f" "$OUT"; DISPATCHED=1
  fi
done
exit 0
