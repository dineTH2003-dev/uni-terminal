#!/usr/bin/env bash

UNISHELL_LOADER_LOADED=1

if [ -n "${BASH_VERSION:-}" ]; then
  _unishell_loader_path="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  _unishell_loader_path="${(%):-%x}"
else
  _unishell_loader_path="$0"
fi

case "$_unishell_loader_path" in
  */*) UNISHELL_HOME="$(cd "$(dirname "$_unishell_loader_path")/.." && pwd -P 2>/dev/null)" ;;
  *) UNISHELL_HOME="$HOME/.unishell" ;;
esac
export UNISHELL_HOME

_unishell_source_file() {
  if [ -f "$1" ]; then
    if [ -n "${ZSH_VERSION:-}" ]; then
      setopt localoptions no_aliases
    fi

    # shellcheck source=/dev/null
    . "$1"
  fi
}

_unishell_clear_command_aliases() {
  unalias unishell uniexit mkassign mkproject openproj cdf editfile jump \
    gstatus gsave gpush glog gnew gundo sysinfo ports myip diskcheck \
    memcheck service-check docker-clean 2>/dev/null || true
}

_unishell_source_file "$UNISHELL_HOME/core/config.sh"
_unishell_clear_command_aliases
_unishell_source_file "$UNISHELL_HOME/core/aliases.sh"
_unishell_source_file "$UNISHELL_HOME/integrations/fzf.sh"
_unishell_source_file "$UNISHELL_HOME/integrations/zoxide.sh"
_unishell_source_file "$UNISHELL_HOME/commands/workspace.sh"
_unishell_source_file "$UNISHELL_HOME/commands/project.sh"
_unishell_source_file "$UNISHELL_HOME/commands/assignment.sh"
_unishell_source_file "$UNISHELL_HOME/commands/navigation.sh"
_unishell_source_file "$UNISHELL_HOME/commands/git.sh"
_unishell_source_file "$UNISHELL_HOME/commands/system.sh"
_unishell_source_file "$UNISHELL_HOME/commands/tools.sh"
_unishell_source_file "$UNISHELL_HOME/commands/doctor.sh"

unset -f _unishell_source_file _unishell_clear_command_aliases
unset _unishell_loader_path
