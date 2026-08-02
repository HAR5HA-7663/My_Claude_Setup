#!/usr/bin/env bash
# Custom 2-line statusline for Harsha

input=$(cat)
g() { echo "$input" | jq -r "$1 // empty"; }

# ── raw values ────────────────────────────────────────────────────────────────
model=$(g '.model.display_name')
cwd=$(g '.workspace.current_dir')
project_dir=$(g '.workspace.project_dir')
used_pct=$(g '.context_window.used_percentage')
five_hour_pct=$(g '.rate_limits.five_hour.used_percentage')
seven_day_pct=$(g '.rate_limits.seven_day.used_percentage')
transcript=$(g '.transcript_path')
effort=$(g '.reasoning_effort')
[ -z "$effort" ] && effort=$(jq -r '.effortLevel // empty' "$HOME/.claude/settings.json" 2>/dev/null)

# ── ANSI ──────────────────────────────────────────────────────────────────────
R="\033[0m"; B="\033[1m"; D="\033[2m"
CYAN="\033[36m"; GREEN="\033[32m"; YEL="\033[33m"; RED="\033[31m"
MAG="\033[35m"; BLUE="\033[34m"; WHITE="\033[97m"; GREY="\033[90m"
SEP="${GREY}│${R}"

# ── dir (shorten ~) ───────────────────────────────────────────────────────────
home="${HOME:-/Users/$(whoami)}"
short_cwd="${cwd/#$home/~}"

# ── git repo/branch ───────────────────────────────────────────────────────────
git_str=""
if [ -n "$cwd" ] && command -v git >/dev/null 2>&1; then
  branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
           || GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    repo_root=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
    repo_name=$(basename "$repo_root")
    git_str=" ${SEP} ${BLUE}${repo_name}/${branch}${R}"
  fi
fi

# ── MCP count ─────────────────────────────────────────────────────────────────
mcp_str=""
if [ -f "$HOME/.claude.json" ]; then
  mcp_names=$(jq -r '.mcpServers // {} | keys | join(",")' "$HOME/.claude.json" 2>/dev/null)
  if [ -n "$mcp_names" ]; then
    mcp_str=" ${SEP} ${D}MCP${R} ${GREEN}${mcp_names}${R}"
  fi
fi

# ── active skill (from transcript tail) ───────────────────────────────────────
skill_str=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  last_skill=$(tail -n 200 "$transcript" 2>/dev/null \
    | jq -r 'select(.message.content?) | .message.content[]? | select(.type=="tool_use" and .name=="Skill") | .input.skill' 2>/dev/null \
    | tail -n 1)
  if [ -n "$last_skill" ] && [ "$last_skill" != "null" ]; then
    skill_str=" ${SEP} ${D}SKILL${R} ${MAG}${last_skill}${R}"
  fi
fi

# ── effort (folds in ultracode) ───────────────────────────────────────────────
# /effort ultracode sets the underlying reasoning effort to "xhigh" (settings
# effortLevel reads "xhigh"), so the raw .reasoning_effort never says "ultracode".
# The only live signal is the harness system-reminder ("Ultracode is on: ...")
# injected EVERY turn while active. Check the transcript TAIL (not whole file) so
# the segment reflects the CURRENT state — a whole-file grep would read a stale
# "on" from earlier in the session forever. The "on:" anchor avoids matching
# prose that merely mentions the feature.
ultra_on=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  tail -n 160 "$transcript" 2>/dev/null | grep -qiE 'ultracode is on[:.]' && ultra_on=1
fi
effort_str=""
if [ -n "$ultra_on" ]; then
  # selected level is ultracode; show it, with the underlying reasoning effort dimmed
  effort_str=" ${SEP} ${D}EFFORT${R} ${B}${MAG}ultracode${R}${effort:+ ${D}${effort}${R}}"
elif [ -n "$effort" ]; then
  case "$effort" in
    max)    effort_str=" ${SEP} ${D}EFFORT${R} ${B}${RED}${effort}${R}" ;;
    xhigh)  effort_str=" ${SEP} ${D}EFFORT${R} ${RED}${effort}${R}" ;;
    high)   effort_str=" ${SEP} ${D}EFFORT${R} ${YEL}${effort}${R}" ;;
    medium) effort_str=" ${SEP} ${D}EFFORT${R} ${GREEN}${effort}${R}" ;;
    low)    effort_str=" ${SEP} ${D}EFFORT${R} ${D}${effort}${R}" ;;
    *)      effort_str=" ${SEP} ${D}EFFORT${R} ${CYAN}${effort}${R}" ;;
  esac
fi

# ── ultracode now folded into the EFFORT segment above (no standalone segment) ─

# ── claude CLI flags (walk parent processes for the claude command) ───────────
claude_cmd=""
pid=$PPID
for i in 1 2 3 4 5 6 7 8; do
  [ -z "$pid" ] || [ "$pid" = "0" ] || [ "$pid" = "1" ] && break
  cmd=$(ps -p "$pid" -o command= 2>/dev/null)
  if echo "$cmd" | grep -qE '(^| )claude( |$)'; then
    claude_cmd="$cmd"
    break
  fi
  pid=$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ')
done
has_flag() { echo "$claude_cmd" | grep -q -- "$1"; }

# CHROME — always shown (user wants explicit on/off)
if has_flag '--chrome'; then
  chrome_str="${D}CHROME${R} ${GREEN}on${R}"
else
  chrome_str="${D}CHROME${R} ${RED}off${R}"
fi

# Flag-only segments — show only when enabled
flags_str=""
if has_flag '--fast'; then
  flags_str="${flags_str} ${SEP} ${D}FAST${R} ${YEL}on${R}"
fi
if has_flag '--debug'; then
  flags_str="${flags_str} ${SEP} ${D}DEBUG${R} ${MAG}on${R}"
fi
if has_flag '--verbose'; then
  flags_str="${flags_str} ${SEP} ${D}VERBOSE${R} ${CYAN}on${R}"
fi
if has_flag '--continue'; then
  flags_str="${flags_str} ${SEP} ${D}CONT${R} ${GREEN}on${R}"
elif has_flag '--resume'; then
  flags_str="${flags_str} ${SEP} ${D}RESUMED${R} ${GREEN}on${R}"
fi

# ── extra usage segment removed per user request ──────────────────────────────

# ── context bar ───────────────────────────────────────────────────────────────
ctx_str=""
if [ -n "$used_pct" ]; then
  u=$(printf "%.0f" "$used_pct")
  filled=$(( u / 10 )); empty=$(( 10 - filled ))
  bar=""
  for i in $(seq 1 $filled 2>/dev/null); do bar="${bar}█"; done
  for i in $(seq 1 $empty 2>/dev/null);  do bar="${bar}░"; done
  if   [ "$u" -ge 90 ]; then c="$RED"
  elif [ "$u" -ge 70 ]; then c="$YEL"
  else                      c="$GREEN"; fi
  ctx_str="${D}CTX${R} ${c}${bar}${R} ${D}${u}%${R}"
fi

# ── token usage (sum from transcript) ─────────────────────────────────────────
tok_str=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  read -r t_in t_out t_cache < <(jq -rs '
    map(select(.message.usage?)) | map(.message.usage) |
    [ (map(.input_tokens // 0) | add // 0),
      (map(.output_tokens // 0) | add // 0),
      (map((.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)) | add // 0) ]
    | "\(.[0]) \(.[1]) \(.[2])"' "$transcript" 2>/dev/null)
  t_in=${t_in:-0}; t_out=${t_out:-0}; t_cache=${t_cache:-0}
  t_total=$(( t_in + t_out + t_cache ))
  fmt() {
    local n=$1
    if   [ "$n" -ge 1000000 ]; then awk "BEGIN{printf \"%.1fM\", $n/1000000}"
    elif [ "$n" -ge 1000 ];    then awk "BEGIN{printf \"%.1fK\", $n/1000}"
    else echo "$n"; fi
  }
  tok_in="${D}IN${R} ${CYAN}$(fmt $t_in)${R}"
  tok_out="${D}OUT${R} ${MAG}$(fmt $t_out)${R}"
  tok_cache="${D}CACHE${R} ${BLUE}$(fmt $t_cache)${R}"
  tok_total="${D}TOT${R} ${B}${WHITE}$(fmt $t_total)${R}"
fi

# ── active workflow + its agent count ─────────────────────────────────────────
# Source of truth: <session_dir>/workflows/wf_*.json (session_dir = transcript
# path minus .jsonl). A workflow is "running" when its status is non-terminal
# AND the file was touched recently (guards against stale/crashed runs).
# agentCount is agents spawned so far — shown as the live worker count.
wf_str=""
if [ -n "$transcript" ]; then
  wf_dir="${transcript%.jsonl}/workflows"
  if [ -d "$wf_dir" ]; then
    now=$(date +%s)
    best_name=""; best_agents=0; best_mtime=0
    for f in "$wf_dir"/wf_*.json; do
      [ -f "$f" ] || continue
      st=$(jq -r '.status // empty' "$f" 2>/dev/null)
      case "$st" in
        ""|completed|complete|done|finished|failed|error|errored|cancelled|canceled|killed|aborted|stopped|timeout) continue ;;
      esac
      mt=$(stat -f %m "$f" 2>/dev/null || echo 0)
      [ $(( now - mt )) -gt 1800 ] && continue   # ignore if untouched > 30 min
      if [ "$mt" -gt "$best_mtime" ]; then
        best_mtime=$mt
        best_name=$(jq -r '.workflowName // "workflow"' "$f" 2>/dev/null)
        best_agents=$(jq -r '.agentCount // 0' "$f" 2>/dev/null)
      fi
    done
    if [ -n "$best_name" ]; then
      wf_str="${D}WF${R} ${B}${YEL}${best_name}${R} ${GREEN}⧗${R} ${MAG}${best_agents}${R}${D}a${R}"
    fi
  fi
fi

# ── rate limits ───────────────────────────────────────────────────────────────
rate_color() {
  local p=$1
  if   [ "$p" -ge 80 ]; then echo "$RED"
  elif [ "$p" -ge 50 ]; then echo "$YEL"
  else                        echo "$GREEN"; fi
}
fh_str=""
if [ -n "$five_hour_pct" ]; then
  p=$(printf "%.0f" "$five_hour_pct")
  fh_str="${D}5H${R} $(rate_color $p)${p}%${R}"
fi
sd_str=""
if [ -n "$seven_day_pct" ]; then
  p=$(printf "%.0f" "$seven_day_pct")
  sd_str="${D}7D${R} $(rate_color $p)${p}%${R}"
fi

# ── assemble ──────────────────────────────────────────────────────────────────
line1="${WHITE}${short_cwd}${R}${git_str}"
[ -n "$model" ] && line1="${line1} ${SEP} ${B}${CYAN}${model}${R}"
line1="${line1}${mcp_str}${skill_str}${effort_str}${flags_str} ${SEP} ${chrome_str}"

line2=""
[ -n "$ctx_str" ] && line2="${ctx_str}"
[ -n "$tok_in" ]    && line2="${line2}${line2:+ ${SEP} }${tok_in}"
[ -n "$tok_out" ]   && line2="${line2}${line2:+ ${SEP} }${tok_out}"
[ -n "$tok_cache" ] && line2="${line2}${line2:+ ${SEP} }${tok_cache}"
[ -n "$tok_total" ]  && line2="${line2}${line2:+ ${SEP} }${tok_total}"
[ -n "$fh_str" ]  && line2="${line2}${line2:+ ${SEP} }${fh_str}"
[ -n "$sd_str" ]     && line2="${line2}${line2:+ ${SEP} }${sd_str}"
[ -n "$wf_str" ] && line2="${line2}${line2:+ ${SEP} }${wf_str}"

printf "%b\n" "$line1"
[ -n "$line2" ] && printf "%b" "$line2"
