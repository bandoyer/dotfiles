# Personal command recipe palette for interactive Bash shells.
# Alt-S searches the Markdown catalog and inserts the selection without running it.

if [[ $- == *i* ]] && command -v cmds >/dev/null 2>&1; then
  _cmds_readline_insert() {
    local original_line="${READLINE_LINE:-}"
    local selected

    selected="$(cmds --print "$original_line")" || return
    [[ -n $selected ]] || return

    READLINE_LINE="$selected"
    READLINE_POINT=${#READLINE_LINE}
  }

  bind -x '"\es":_cmds_readline_insert'
fi
