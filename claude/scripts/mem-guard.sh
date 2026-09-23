#!/bin/bash
# mem-guard.sh — macOS memory guard for Claude Code + launchd.
#   mem-guard.sh status   -> print current metrics (human)
#   mem-guard.sh hook     -> Claude Code PreToolUse hook (Agent|Workflow): deny spawns under pressure
#   mem-guard.sh watch    -> launchd tick: log metrics, and under pressure kill idle spares + notify
#
# Thresholds (override in ~/.config/mem-guard.env):
#   PRESSURE_DENY=2        kern.memorystatus_vm_pressure_level: 1=normal 2=warn 4=critical
#   SWAP_DENY_MB=2048      swap in use
#   COMP_DENY_MB=9000      compressor size (5-6 GB is NORMAL on this 16 GB Mac; OOM came at 8.1 GB)
#   AVAIL_CRIT_PCT=10      kern.memorystatus_level (% "available") below this = critical
# Test toggle: touch ~/.local/state/mem-guard/force-deny  (hook denies, watch acts) — remove after testing.
set -u
STATE="$HOME/.local/state/mem-guard"; mkdir -p "$STATE"
LOG="$STATE/mem-guard.log"
PRESSURE_DENY=2; SWAP_DENY_MB=2048; COMP_DENY_MB=9000; AVAIL_CRIT_PCT=10
NOTIFY_THROTTLE_S=600; KILL_THROTTLE_S=300
[ -f "$HOME/.config/mem-guard.env" ] && . "$HOME/.config/mem-guard.env"

metrics() {
  PAGE=$(/usr/bin/vm_stat | /usr/bin/awk 'NR==1{gsub(/[^0-9]/,"",$0); print}')
  eval "$(/usr/bin/vm_stat | /usr/bin/awk -v p="$PAGE" '
    /Pages free/              {f=$NF}
    /Pages speculative/       {s=$NF}
    /occupied by compressor/  {c=$NF}
    END{gsub(/\./,"",f);gsub(/\./,"",s);gsub(/\./,"",c);
        printf "FREE_MB=%d COMP_MB=%d\n",(f+s)*p/1048576,c*p/1048576}')"
  SWAP_MB=$(/usr/sbin/sysctl -n vm.swapusage | /usr/bin/awk '{for(i=1;i<=NF;i++) if($i=="used"){v=$(i+2); sub(/M$/,"",v); print int(v)}}')
  LEVEL=$(/usr/sbin/sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null || echo 1)
  AVAIL_PCT=$(/usr/sbin/sysctl -n kern.memorystatus_level 2>/dev/null || echo 100)
  TOTAL_MB=$(( $(/usr/sbin/sysctl -n hw.memsize) / 1048576 ))
}

under_pressure() {
  [ -f "$STATE/force-deny" ] && { REASON="force-deny test toggle present"; return 0; }
  if [ "$LEVEL" -ge "$PRESSURE_DENY" ]; then REASON="macOS pressure level $LEVEL (2=warn,4=critical)"; return 0; fi
  if [ "$SWAP_MB" -ge "$SWAP_DENY_MB" ]; then REASON="swap in use ${SWAP_MB} MB >= ${SWAP_DENY_MB}"; return 0; fi
  if [ "$COMP_MB" -ge "$COMP_DENY_MB" ]; then REASON="compressor ${COMP_MB} MB >= ${COMP_DENY_MB}"; return 0; fi
  if [ "$AVAIL_PCT" -lt "$AVAIL_CRIT_PCT" ]; then REASON="available ${AVAIL_PCT}% < ${AVAIL_CRIT_PCT}%"; return 0; fi
  return 1
}

top_hogs() {  # top N processes by RSS, one line
  /bin/ps -eo rss,comm | /usr/bin/awk 'NR>1{n=$2; sub(/^.*\//,"",n); a[n]+=$1} END{for(k in a) printf "%d %s\n",a[k]/1024,k}' \
    | /usr/bin/sort -rn | /usr/bin/head -"${1:-6}" | /usr/bin/awk '{printf "%s %sMB; ",$2,$1}'
}

throttled() {  # throttled <name> <seconds> -> 0 if allowed now (and stamps), 1 if throttled
  local f="$STATE/.last-$1" now; now=$(date +%s)
  if [ -f "$f" ] && [ $(( now - $(cat "$f") )) -lt "$2" ]; then return 1; fi
  echo "$now" > "$f"; return 0
}

case "${1:-status}" in
  status)
    metrics
    printf "total=%dMB free=%dMB compressor=%dMB swap=%dMB pressure_level=%s available=%s%%\n" \
      "$TOTAL_MB" "$FREE_MB" "$COMP_MB" "$SWAP_MB" "$LEVEL" "$AVAIL_PCT"
    if under_pressure; then echo "STATE: PRESSURE ($REASON)"; else echo "STATE: ok"; fi
    echo "top: $(top_hogs 8)"
    ;;
  hook)
    IN=$(cat)  # PreToolUse JSON on stdin
    metrics
    if under_pressure; then
      TOOL=$(printf '%s' "$IN" | /usr/bin/sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
      MSG="mem-guard: refusing to spawn ${TOOL:-subagent} — $REASON. RAM ${TOTAL_MB}MB, free ${FREE_MB}MB, compressor ${COMP_MB}MB, swap ${SWAP_MB}MB. Top: $(top_hogs 5)Free memory (close Chrome tabs / idle claude sessions, ) then retry, or do the work inline without subagents."
      echo "$(date '+%F %T') HOOK deny tool=${TOOL:-?} $REASON free=${FREE_MB} comp=${COMP_MB} swap=${SWAP_MB}" >> "$LOG"
      /usr/bin/python3 -c 'import json,sys;print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":sys.argv[1]}}))' "$MSG"
    fi
    exit 0
    ;;
  watch)
    metrics
    if under_pressure; then
      ACT=""
      # NEVER kill claude bg-spare/bg-pty-host processes: claimed background workers keep the
      # same argv as idle spares, so any pattern kill takes down live agents (happened 2026-09-17).
      # 2. Spotlight UI process (bloats, relaunches on demand)
      if /usr/bin/pgrep -x Spotlight >/dev/null && throttled spotlight 1800; then /usr/bin/killall Spotlight 2>/dev/null; ACT="$ACT restarted-Spotlight"; fi
      # 3. notify (throttled)
      if throttled notify "$NOTIFY_THROTTLE_S"; then
        /usr/bin/osascript -e "display notification \"$REASON. free ${FREE_MB}MB, compressor ${COMP_MB}MB, swap ${SWAP_MB}MB. Actions:${ACT:- none}\" with title \"Memory guard\" subtitle \"Close Chrome tabs / idle sessions\"" 2>/dev/null
        ACT="$ACT notified"
      fi
      echo "$(date '+%F %T') PRESSURE $REASON free=${FREE_MB} comp=${COMP_MB} swap=${SWAP_MB} lvl=$LEVEL avail=${AVAIL_PCT}% actions:${ACT:- none} | top: $(top_hogs 8)" >> "$LOG"
    else
      echo "$(date '+%F %T') ok free=${FREE_MB} comp=${COMP_MB} swap=${SWAP_MB} lvl=$LEVEL avail=${AVAIL_PCT}%" >> "$LOG"
    fi
    # rotate: keep last 20k lines
    if [ "$(/usr/bin/wc -l < "$LOG")" -gt 25000 ]; then /usr/bin/tail -n 20000 "$LOG" > "$LOG.tmp" && /bin/mv "$LOG.tmp" "$LOG"; fi
    ;;
  *) echo "usage: $0 status|hook|watch"; exit 2;;
esac
