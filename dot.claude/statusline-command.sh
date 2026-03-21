#!/bin/sh
# Claude Code status line — styled after myprompt1

input=$(cat)

user=$(whoami)
host=$(hostname -s)
pwd_val=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // empty')
session_name=$(echo "$input" | jq -r '.session_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

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

printf '\n'
