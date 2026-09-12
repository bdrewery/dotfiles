#!/bin/sh
# Claude Code status line — styled after myprompt1

input=$(cat)

user=$(whoami)
host=$(hostname -s)
pwd_val=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // empty')
session_name=$(echo "$input" | jq -r '.session_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
limit_five_hour=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
limit_five_hour_resets_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
limit_seven_day=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
limit_seven_day_resets_at=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Publish this blob for hooks to read.
#
# The status line is the only place Claude Code hands over
# .context_window.used_percentage and .session_name; hook payloads carry
# neither. Without this, anything wanting to know how full the window is has
# to infer it from transcript byte growth, which needs a learned window size
# and is simply wrong until the first compaction happens.
#
# Written whole rather than picked apart, so this script encodes nothing about
# what any consumer wants -- a reader takes the fields it needs and this stays
# a dumb pipe. Landed in the worktree's git dir: per-worktree, never
# committed, and already where hook state lives.
#
# Best-effort by construction. Every failure path is silent, because a status
# line that breaks a prompt over a diagnostic file is worse than no file.
if [ -n "${pwd_val:-}" ] && [ -d "${pwd_val:-}" ]; then
	_gitdir=$(cd "$pwd_val" 2>/dev/null && git rev-parse --git-dir 2>/dev/null) || _gitdir=""
	case "${_gitdir:-}" in
	"") ;;
	/*) ;;
	*) _gitdir="${pwd_val}/${_gitdir}" ;;
	esac
	if [ -n "${_gitdir:-}" ] && [ -d "${_gitdir:-}" ]; then
		printf '%s' "$input" >"${_gitdir}/claude-statusline.json.tmp" 2>/dev/null &&
			mv -f "${_gitdir}/claude-statusline.json.tmp" \
				"${_gitdir}/claude-statusline.json" 2>/dev/null
	fi
	unset _gitdir
fi

# [user@host]
printf '\033[31m[\033[0m\033[32m%s\033[37m@\033[32m%s\033[31m]\033[0m' "$user" "$host"

# [Day MM/DD/YYYY HH:MM:SS]
printf ' \033[37m[\033[33m%s\033[37m]\033[0m' "$(date '+%a %m/%d/%Y %T')"

# [~/path]
home="$HOME"
display_pwd="${pwd_val#"$home"}"
if [ "$display_pwd" != "$pwd_val" ]; then
  display_pwd="~$display_pwd"
fi
printf ' \033[31m%s\033[0m' "$display_pwd"

# [model] if available
if [ -n "$model" ]; then
  printf ' \033[37m[\033[36m%s\033[37m]\033[0m' "$model"
fi

# [name: session name] if set
if [ -n "$session_name" ]; then
  printf ' \033[37m[\033[36mname: %s\033[37m]\033[0m' "$session_name"
fi

# [ctx: N% used] if available
if [ -n "$used" ]; then
  printf ' \033[37m[\033[33mctx: %s%%\033[37m]\033[0m' "$(printf '%.0f' "$used")"
fi

# [limit: N%(Xh)/N%(Xd)] if available
if [ -n "$limit_five_hour" ] && [ -n "$limit_seven_day" ]; then
  now=$(date +%s)
  minutes_threshold=5400  # show minutes when <= 90 minutes remain
  five_hr_pct=$(printf '%.0f' "$limit_five_hour")
  seven_day_pct=$(printf '%.0f' "$limit_seven_day")
  if [ -n "$limit_five_hour_resets_at" ]; then
    five_hr_secs=$(( limit_five_hour_resets_at - now ))
    if [ "$five_hr_secs" -le "$minutes_threshold" ]; then
      five_hr_min=$(( (five_hr_secs + 59) / 60 ))
      five_hr_label="${five_hr_pct}%(${five_hr_min}m)"
    else
      five_hr_left=$(( (five_hr_secs + 3599) / 3600 ))
      five_hr_label="${five_hr_pct}%(${five_hr_left}h)"
    fi
  else
    five_hr_label="${five_hr_pct}%"
  fi
  if [ -n "$limit_seven_day_resets_at" ]; then
    seven_day_secs=$(( limit_seven_day_resets_at - now ))
    if [ "$seven_day_secs" -le "$minutes_threshold" ]; then
      seven_day_min=$(( (seven_day_secs + 59) / 60 ))
      seven_day_label="${seven_day_pct}%(${seven_day_min}m)"
    else
      seven_day_left=$(( (seven_day_secs + 86399) / 86400 ))
      seven_day_label="${seven_day_pct}%(${seven_day_left}d)"
    fi
  else
    seven_day_label="${seven_day_pct}%"
  fi
  printf ' \033[37m[\033[38;5;183mlimit: %s/%s\033[37m]\033[0m' "$five_hr_label" "$seven_day_label"
fi

printf '\n'
