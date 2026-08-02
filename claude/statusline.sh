#!/usr/bin/env bash
# ClaudeCodeStatusLine — https://github.com/daniel3303/ClaudeCodeStatusLine
# Installed automatically by Claude Code status line setup agent.

input=$(cat)

# ── helpers ──────────────────────────────────────────────────────────────────
get() { echo "$input" | jq -r "$1 // empty"; }

# ── raw values ────────────────────────────────────────────────────────────────
model=$(get '.model.display_name')
cwd=$(get '.workspace.current_dir')
project_dir=$(get '.workspace.project_dir')
used_pct=$(get '.context_window.used_percentage')
remaining_pct=$(get '.context_window.remaining_percentage')
five_hour_pct=$(get '.rate_limits.five_hour.used_percentage')
seven_day_pct=$(get '.rate_limits.seven_day.used_percentage')
vim_mode=$(get '.vim.mode')
session_name=$(get '.session_name')
worktree_branch=$(get '.worktree.branch')
git_worktree=$(get '.workspace.git_worktree')
effort=$(get '.reasoning_effort')

# ── ANSI colours ──────────────────────────────────────────────────────────────
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

FG_WHITE="\033[97m"
FG_CYAN="\033[36m"
FG_GREEN="\033[32m"
FG_YELLOW="\033[33m"
FG_RED="\033[31m"
FG_MAGENTA="\033[35m"
FG_BLUE="\033[34m"
FG_BRIGHT_BLACK="\033[90m"   # grey

# ── git branch (fast, lock-safe) ───────────────────────────────────────────────
git_branch=""
if [ -n "$cwd" ] && command -v git >/dev/null 2>&1; then
  git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
               || GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Prefer worktree branch info when available
if [ -n "$worktree_branch" ]; then
  git_branch="$worktree_branch"
fi

# ── context bar (10-char wide) ─────────────────────────────────────────────────
context_bar=""
if [ -n "$used_pct" ]; then
  # Round to integer
  used_int=$(printf "%.0f" "$used_pct")
  filled=$(( used_int / 10 ))
  empty=$(( 10 - filled ))
  bar=""
  for i in $(seq 1 $filled);  do bar="${bar}█"; done
  for i in $(seq 1 $empty);   do bar="${bar}░"; done

  if   [ "$used_int" -ge 90 ]; then bar_color="$FG_RED"
  elif [ "$used_int" -ge 70 ]; then bar_color="$FG_YELLOW"
  else                               bar_color="$FG_GREEN"
  fi
  context_bar="${bar_color}${bar}${RESET} ${DIM}${used_int}%${RESET}"
fi

# ── rate-limit section ─────────────────────────────────────────────────────────
rate_str=""
if [ -n "$five_hour_pct" ]; then
  fh_int=$(printf "%.0f" "$five_hour_pct")
  if   [ "$fh_int" -ge 80 ]; then fh_color="$FG_RED"
  elif [ "$fh_int" -ge 50 ]; then fh_color="$FG_YELLOW"
  else                             fh_color="$FG_GREEN"
  fi
  rate_str="${DIM}5h:${RESET}${fh_color}${fh_int}%${RESET}"
fi
if [ -n "$seven_day_pct" ]; then
  sd_int=$(printf "%.0f" "$seven_day_pct")
  if   [ "$sd_int" -ge 80 ]; then sd_color="$FG_RED"
  elif [ "$sd_int" -ge 50 ]; then sd_color="$FG_YELLOW"
  else                             sd_color="$FG_GREEN"
  fi
  sep=""
  [ -n "$rate_str" ] && sep=" "
  rate_str="${rate_str}${sep}${DIM}7d:${RESET}${sd_color}${sd_int}%${RESET}"
fi

# ── vim mode ───────────────────────────────────────────────────────────────────
vim_str=""
if [ -n "$vim_mode" ]; then
  if [ "$vim_mode" = "NORMAL" ]; then
    vim_str="${BOLD}${FG_YELLOW} NORMAL${RESET}"
  else
    vim_str="${BOLD}${FG_GREEN} INSERT${RESET}"
  fi
fi

# ── effort ─────────────────────────────────────────────────────────────────────
effort_str=""
if [ -n "$effort" ]; then
  if [ "$effort" = "max" ]; then
    effort_str=" ${FG_RED}⚡max${RESET}"
  elif [ "$effort" = "high" ]; then
    effort_str=" ${FG_YELLOW}⚡high${RESET}"
  elif [ "$effort" = "low" ]; then
    effort_str=" ${DIM}⚡low${RESET}"
  else
    effort_str=" ${FG_GREEN}⚡${effort}${RESET}"
  fi
fi

# ── session name ───────────────────────────────────────────────────────────────
session_str=""
if [ -n "$session_name" ]; then
  session_str=" ${DIM}[${session_name}]${RESET}"
fi

# ── git worktree label ─────────────────────────────────────────────────────────
worktree_str=""
if [ -n "$git_worktree" ]; then
  worktree_str=" ${FG_MAGENTA}⎇ wt:${git_worktree}${RESET}"
fi

# ── shorten cwd ────────────────────────────────────────────────────────────────
home_dir="${HOME:-/Users/$(whoami)}"
short_cwd="${cwd/#$home_dir/~}"

# ── assemble line ──────────────────────────────────────────────────────────────
line=""

# Model
if [ -n "$model" ]; then
  line="${line}${BOLD}${FG_CYAN}${model}${RESET}"
fi

# Effort
line="${line}${effort_str}"

# Session name
line="${line}${session_str}"

# Vim mode
line="${line}${vim_str}"

# Separator
if [ -n "$line" ]; then
  line="${line} ${FG_BRIGHT_BLACK}|${RESET} "
fi

# Directory
if [ -n "$short_cwd" ]; then
  line="${line}${FG_WHITE}${short_cwd}${RESET}"
fi

# Git branch
if [ -n "$git_branch" ]; then
  line="${line} ${FG_BLUE}(${git_branch})${RESET}"
fi

# Git worktree
line="${line}${worktree_str}"

# Context window
if [ -n "$context_bar" ]; then
  line="${line} ${FG_BRIGHT_BLACK}|${RESET} ctx:${context_bar}"
fi

# Rate limits
if [ -n "$rate_str" ]; then
  line="${line} ${FG_BRIGHT_BLACK}|${RESET} ${rate_str}"
fi

printf "%b\n" "$line"
