#!/usr/bin/env bash

_unishell_load_zoxide() {
  export UNISHELL_ZOXIDE_AVAILABLE=0
  : "${UNISHELL_ZOXIDE_ENABLED:=0}"

  if [ "${UNISHELL_ENABLE_ZOXIDE:-1}" = "0" ]; then
    export UNISHELL_ZOXIDE_ENABLED=0
    return 0
  fi

  if ! command -v zoxide >/dev/null 2>&1; then
    export UNISHELL_ZOXIDE_ENABLED=0
    return 0
  fi

  export UNISHELL_ZOXIDE_AVAILABLE=1

  case "$-" in
    *i*) ;;
    *)
      export UNISHELL_ZOXIDE_ENABLED
      return 0
      ;;
  esac

  local shell_name=""
  if [ -n "${ZSH_VERSION:-}" ]; then
    shell_name="zsh"
  elif [ -n "${BASH_VERSION:-}" ]; then
    shell_name="bash"
  else
    return 0
  fi

  local zoxide_cmd="${UNISHELL_ZOXIDE_CMD:-j}"
  local init_script=""
  init_script="$(zoxide init "$shell_name" --cmd "$zoxide_cmd" 2>/dev/null)" || return 0

  if [ -n "$init_script" ]; then
    eval "$init_script"
    export UNISHELL_ZOXIDE_ENABLED=1
  fi
}

_unishell_load_zoxide
unset -f _unishell_load_zoxide 2>/dev/null || true
