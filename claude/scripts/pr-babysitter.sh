#!/usr/bin/env bash
# PR babysitter — keeps a PR's branch mergeable and watches its checks until green.
#
# What it DOES (safely, deterministically):
#   - Syncs the head branch when it falls behind base *conflict-free* (merge base
#     in, IOC-scan, push). This is the common "branch behind main" block.
#   - Polls checks until they all pass, then stops.
# What it does NOT do (escalates instead — a script can't judge these):
#   - Resolve REAL merge conflicts (aborts the merge, alerts, stops).
#   - Fix a FAILING check that needs a code change (alerts with the failure, stops).
#
# Never commits, never `git add`, never force-pushes, never switches branches.
# Only ever: merge origin/<base> into the *current* head branch + push, when the
# tree is clean and the merge is conflict-free.
#
# Usage: pr-babysitter.sh <github-pr-url>
set -uo pipefail

URL="${1:-}"
[ -z "$URL" ] && exit 0
echo "$URL" | grep -qE '^https://github\.com/[^/]+/[^/]+/pull/[0-9]+' || exit 0

OWNER=$(echo "$URL" | sed -E 's#https://github.com/([^/]+)/([^/]+)/pull/([0-9]+).*#\1#')
REPO=$(echo  "$URL" | sed -E 's#https://github.com/([^/]+)/([^/]+)/pull/([0-9]+).*#\2#')
PR=$(echo    "$URL" | sed -E 's#https://github.com/([^/]+)/([^/]+)/pull/([0-9]+).*#\3#')

# Map GitHub repo -> local checkout (Bevri repos). Extend as needed.
case "$REPO" in
  API-backend)      DIR="$HOME/Desktop/Bevri/API-backend" ;;
  bevri-web-portal) DIR="$HOME/Desktop/Bevri/bevri-web-portal" ;;
  bevri-prisma)     DIR="$HOME/Desktop/Bevri/bevri-prisma" ;;
  *)                DIR="" ;;
esac
[ -z "$DIR" ] || [ ! -d "$DIR/.git" ] && { echo "no local checkout for $REPO — nothing to babysit"; exit 0; }

LOG="$HOME/.claude/pr-babysitter-${REPO}-${PR}.log"
# Single instance per PR — mkdir is atomic (macOS has no flock).
LOCKDIR="$HOME/.claude/pr-babysitter-${REPO}-${PR}.lock.d"
mkdir "$LOCKDIR" 2>/dev/null || { echo "already babysitting $REPO#$PR"; exit 0; }
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT

# BeaverTail IOC signature — refuse to push if a merge drags one in.
IOC="global\['\!'\]|_\$_1e42|node -e global|trongrid\.io|aptoslabs\.com|bsc-dataseed|eth_getTransactionByHash"

notify() {
  local tag="$1"; shift; local msg="$*"
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$tag] $msg" >> "$LOG"
  osascript -e "display notification \"$msg\" with title \"PR babysitter · $REPO#$PR · $tag\"" 2>/dev/null || true
}

# Verify the merged tree is clean of IOCs, then push. Used by both the
# conflict-free path and the agent-resolved path.
ioc_scan_and_push() {
  local how="$1"
  if git -C "$DIR" grep -I -l -E "$IOC" HEAD 2>/dev/null | grep -v malware-ioc-check | head -1 >/dev/null; then
    notify HALT "IOC signature present after $how — NOT pushing, manual review needed"; return 1
  fi
  if git -C "$DIR" push origin "$HEAD" >> "$LOG" 2>&1; then
    notify SYNCED "$how — pushed $HEAD"; return 0
  fi
  notify PUSHFAIL "$how ok but push failed — see log"; return 1
}

# A real merge conflict needs judgment about what the change MEANT, which the
# session that wrote it has and a fresh agent does not. So we do not resolve it
# here: we capture what conflicts, abort the merge (never leave a shared branch
# in a conflicted state), and exit 2 — the asyncRewake hook turns that exit code
# plus this stdout into a wake-up for the session that opened the PR.
handback_conflict() {
  local files
  files=$(git -C "$DIR" diff --name-only --diff-filter=U | sed 's/^/  - /')
  git -C "$DIR" merge --abort 2>/dev/null   # leave the shared tree clean
  notify HANDBACK "conflicts with origin/$BASE — handed back to the session that opened the PR"
  cat <<EOF
PR #$PR ($OWNER/$REPO) cannot merge: branch '$HEAD' CONFLICTS with 'origin/$BASE'.

Conflicting files:
$files

You opened this PR, so you have the context to resolve it correctly — do it now,
before other work. In $DIR (already on '$HEAD', tree is clean — the probe merge
was aborted):

  git -C $DIR fetch origin
  git -C $DIR merge origin/$BASE

Then resolve each conflict PRESERVING BOTH SIDES: keep the incoming
'origin/$BASE' changes AND your branch's changes. Dropping either side is a
failure, not a resolution. This branch is shared by other agents, so touch only
the conflicted files, never run checkout/switch/stash/reset, and stage only
those paths.

If a genuine either/or decision is needed (two sides changed the same logic
incompatibly), run 'git -C $DIR merge --abort' and ask Harsha instead of guessing.

After committing the merge, push with: git -C $DIR push origin $HEAD
Auto-merge is already armed, so the PR merges itself once checks pass and it is
approved.
EOF
  exit 2
}

notify START "watching PR (base sync + conflict resolution + checks until green)"

for i in $(seq 1 40); do   # 40 * 30s = up to 20 min
  git -C "$DIR" fetch origin --quiet 2>/dev/null

  META=$(gh pr view "$PR" --repo "$OWNER/$REPO" --json state,mergeable,mergeStateStatus,baseRefName,headRefName 2>/dev/null)
  [ -z "$META" ] && { sleep 30; continue; }
  PRSTATE=$(echo "$META" | jq -r '.state')
  BASE=$(echo    "$META" | jq -r '.baseRefName')
  HEAD=$(echo    "$META" | jq -r '.headRefName')
  MERGEABLE=$(echo "$META" | jq -r '.mergeable')
  MSTATUS=$(echo   "$META" | jq -r '.mergeStateStatus')

  if [ "$PRSTATE" = "MERGED" ] || [ "$PRSTATE" = "CLOSED" ]; then
    notify DONE "PR is $PRSTATE — stopping"; exit 0
  fi

  # --- conflict-free base sync ---
  if [ "$MERGEABLE" = "CONFLICTING" ] || [ "$MSTATUS" = "BEHIND" ] || [ "$MSTATUS" = "DIRTY" ]; then
    CUR=$(git -C "$DIR" rev-parse --abbrev-ref HEAD)
    if [ "$CUR" != "$HEAD" ]; then
      notify SKIP "local checkout is on '$CUR', PR head is '$HEAD' — not touching it"
    elif [ -n "$(git -C "$DIR" status --porcelain)" ]; then
      notify SKIP "working tree has uncommitted changes — not syncing (avoid stomping in-progress work)"
    elif git -C "$DIR" merge "origin/$BASE" --no-edit >> "$LOG" 2>&1; then
      ioc_scan_and_push "merged origin/$BASE (conflict-free)" || exit 1
    else
      handback_conflict   # captures files, aborts the merge, exits 2 to wake the PR's session
    fi
  fi

  # --- checks: gh exit code is the signal (0 all pass, 8 pending, else failing) ---
  gh pr checks "$PR" --repo "$OWNER/$REPO" >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq 0 ]; then
    notify GREEN "all checks passed ✅ (mergeable=$MERGEABLE, mergeState=$MSTATUS) — auto-merge armed, merges once approvals land"; exit 0
  elif [ "$rc" -eq 8 ]; then
    :  # some checks still running — keep watching
  else
    notify CHECKFAIL "a check is FAILING — needs a fix (not auto-fixable):"
    gh pr checks "$PR" --repo "$OWNER/$REPO" 2>&1 | grep -iE 'fail|error' >> "$LOG"
    exit 1
  fi

  sleep 30
done

notify TIMEOUT "checks still pending after ~20 min — stopping (re-launch to keep watching)"
