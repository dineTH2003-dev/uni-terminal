#!/usr/bin/env bash

_unishell_load_fzf() {
  export UNISHELL_FZF_AVAILABLE=0
  : "${UNISHELL_FZF_ENABLED:=0}"

  if [ "${UNISHELL_ENABLE_FZF:-1}" = "0" ]; then
    export UNISHELL_FZF_ENABLED=0
    return 0
  fi

  if ! command -v fzf >/dev/null 2>&1; then
    export UNISHELL_FZF_ENABLED=0
    return 0
  fi

  export UNISHELL_FZF_AVAILABLE=1
  : "${FZF_DEFAULT_OPTS:=--height=40% --layout=reverse --border}"
  export FZF_DEFAULT_OPTS

  case "$-" in
    *i*) ;;
    *)
      export UNISHELL_FZF_ENABLED
      return 0
      ;;
  esac

  local integration_script=""
  if [ -n "${ZSH_VERSION:-}" ]; then
    integration_script="$(fzf --zsh 2>/dev/null)" || return 0
  elif [ -n "${BASH_VERSION:-}" ]; then
    integration_script="$(fzf --bash 2>/dev/null)" || return 0
  else
    return 0
  fi

  if [ -n "$integration_script" ]; then
    eval "$integration_script"
    export UNISHELL_FZF_ENABLED=1
  fi
}

_unishell_load_fzf
unset -f _unishell_load_fzf 2>/dev/null || true
