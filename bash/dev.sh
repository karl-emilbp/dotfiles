#!/usr/bin/env bash
# Usage:
#   dev              open the workspace for the current project (or reattach to it)
#   dev stop         close it: quits Neovim cleanly (wherever it runs), asks before killing
#                    anything still running
#   dev stop -f      close it without asking (Neovim with unsaved changes still stops it)
#   dev ls           list open workspaces
#
# Ctrl-h/j/k/l moves between panes, Alt-z zooms the current pane to full screen and back.
set -euo pipefail

# Layout
RIGHT_WIDTH="38%"     # width of the right column
RIGHT2_HEIGHT="50%"   # height of RIGHT2 within the right column (50% = equal halves)

# Command to start in each pane ("" = just a shell)
LEFT_CMD="nvim ."
RIGHT1_CMD=""
RIGHT2_CMD=""

FOCUS="LEFT"          # pane to focus on open: LEFT, RIGHT1 or RIGHT2

dir=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
name=$(basename "$dir" | tr '.: ' '___')

open_workspace() {
  if ! tmux has-session -t "=$name" 2>/dev/null; then
    local cols lines left right1 right2
    cols=$(tput cols 2>/dev/null || echo 250)
    lines=$(tput lines 2>/dev/null || echo 65)

    left=$(tmux new-session -d -P -F '#{pane_id}' -s "$name" -n main -c "$dir" -x "$cols" -y "$lines")
    right1=$(tmux split-window -h -P -F '#{pane_id}' -t "$left" -l "$RIGHT_WIDTH" -c "$dir")
    right2=$(tmux split-window -v -P -F '#{pane_id}' -t "$right1" -l "$RIGHT2_HEIGHT" -c "$dir")

    run_in() { if [ -n "$2" ]; then tmux send-keys -t "$1" "$2" Enter; fi; }
    run_in "$left" "$LEFT_CMD"
    run_in "$right1" "$RIGHT1_CMD"
    run_in "$right2" "$RIGHT2_CMD"

    case "$FOCUS" in
      RIGHT1) tmux select-pane -t "$right1" ;;
      RIGHT2) tmux select-pane -t "$right2" ;;
      *) tmux select-pane -t "$left" ;;
    esac
  fi

  if [ -n "${TMUX:-}" ]; then
    exec tmux switch-client -t "=$name"
  else
    exec tmux attach-session -t "=$name"
  fi
}

nvim_panes() {
  tmux list-panes -s -t "=$1" -F '#{pane_id} #{pane_current_command}' | awk '$2 ~ /^n?vim/ {print $1}'
}

stop_workspace() {
  local force=0 target=""
  for arg in "$@"; do
    case "$arg" in
      -f|--force) force=1 ;;
      *) target=$arg ;;
    esac
  done
  # Inside tmux, default to the workspace you're in; otherwise the current project's
  if [ -z "$target" ]; then
    if [ -n "${TMUX:-}" ]; then target=$(tmux display-message -p '#S'); else target=$name; fi
  fi
  if ! tmux has-session -t "=$target" 2>/dev/null; then
    echo "No workspace '$target' is open."
    return 0
  fi

  # 1. Quit Neovim cleanly, in whichever pane(s) it runs. :qa refuses if there are unsaved changes, which stops us here.
  local pane
  for pane in $(nvim_panes "$target"); do
    tmux send-keys -t "$pane" Escape
    sleep 0.1
    tmux send-keys -t "$pane" ":qa" Enter
  done
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ -z "$(nvim_panes "$target")" ] && break
    sleep 0.2
  done
  if [ -n "$(nvim_panes "$target")" ]; then
    echo "Neovim has unsaved changes in '$target'. Save (:wa) or discard (:qa!) them, then run 'dev stop' again."
    return 1
  fi

  # 2. Anything still running besides an idle shell?
  local busy
  busy=$(tmux list-panes -s -t "=$target" -F '#{pane_current_command}' |
    grep -vxE 'bash|zsh|fish|sh|dash' | sort | uniq -c | awk '{print $2 ($1 > 1 ? " x" $1 : "")}' | paste -sd, - | sed 's/,/, /g' || true)
  if [ -n "$busy" ] && [ "$force" -eq 0 ]; then
    local answer
    read -r -p "Still running in '$target': $busy. Close anyway? [y/N] " answer </dev/tty
    case "$answer" in y|Y|yes) ;; *) echo "Cancelled."; return 1 ;; esac
  fi

  # 3. Close it (if we're inside this session, this also closes our own pane — that's the last step)
  tmux kill-session -t "=$target"
}

case "${1:-}" in
  stop) shift; stop_workspace "$@" ;;
  ls) tmux list-sessions -F '#{session_name}  (#{session_windows} window, #{?session_attached,attached,detached})' 2>/dev/null || echo "No workspaces open." ;;
  ""|open) open_workspace ;;
  *) echo "Usage: dev [stop [-f] [name] | ls]" >&2; exit 2 ;;
esac