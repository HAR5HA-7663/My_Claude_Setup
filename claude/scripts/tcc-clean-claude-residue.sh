#!/bin/bash
# tcc-clean-claude-residue.sh
# Removes stale per-version Claude Code rows from the user TCC database
# (Microphone, AppleEvents, MediaLibrary, FileProvider, folder grants, ...).
# Claude Code's installer keeps each release at ~/.local/share/claude/versions/<v>;
# macOS keys privacy grants to that path, so every update strands the old rows.
#
# MUST run as a child of a Claude Code session (SessionStart hook): hook
# processes inherit the claude binary's Full Disk Access attribution, which is
# required to open TCC.db. launchd/cron cannot run this — no FDA there.
#
# Fast no-op unless the installed claude version changed since the last run.
# The system TCC.db (Full Disk Access / Screen Recording panes) needs root and
# is NOT touched here — clear those rows manually in System Settings.

set -uo pipefail

VERSIONS_DIR="$HOME/.local/share/claude/versions"
DB="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
STATE="$HOME/.claude/scripts/.tcc-clean-last-version"
LOG="$HOME/.claude/scripts/tcc-clean.log"
BACKUP_DIR="$HOME/.claude/tcc-backups"

current="$(basename "$(readlink "$HOME/.local/bin/claude" 2>/dev/null)" 2>/dev/null)"
[ -z "$current" ] || [ "$current" = "." ] && exit 0

# Fast path: no update since last successful run.
[ -f "$STATE" ] && [ "$(cat "$STATE" 2>/dev/null)" = "$current" ] && exit 0

ts() { date '+%Y-%m-%d %H:%M:%S'; }

# Versions still installed on disk keep their grants.
live=""
for v in "$VERSIONS_DIR"/*; do
  [ -e "$v" ] || continue
  live="$live,'$v'"
done
live="${live#,}"
[ -z "$live" ] && exit 0

mkdir -p "$BACKUP_DIR"
cp "$DB" "$BACKUP_DIR/user-TCC-$(date +%Y%m%d-%H%M%S).db" 2>>"$LOG" || {
  echo "$(ts) ERROR: backup failed, aborting (version $current)" >>"$LOG"
  exit 0
}
# Keep only the 5 most recent backups.
ls -t "$BACKUP_DIR"/user-TCC-*.db 2>/dev/null | tail -n +6 | while read -r f; do rm -f "$f"; done

deleted="$(sqlite3 "$DB" "DELETE FROM access WHERE client LIKE '$VERSIONS_DIR/%' AND client NOT IN ($live); SELECT changes();" 2>>"$LOG")" || {
  echo "$(ts) ERROR: sqlite delete failed (version $current)" >>"$LOG"
  exit 0
}

if [ "${deleted:-0}" -gt 0 ] 2>/dev/null; then
  killall tccd 2>/dev/null
  echo "$(ts) cleaned $deleted stale TCC rows (now on $current)" >>"$LOG"
  echo "TCC cleanup: removed $deleted stale Claude version privacy rows"
else
  echo "$(ts) no stale rows (version $current)" >>"$LOG"
fi

echo "$current" >"$STATE"
exit 0
