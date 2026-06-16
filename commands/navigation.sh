#!/usr/bin/env bash

_unishell_require_fzf() {
  if command -v fzf >/dev/null 2>&1; then
    return 0
  fi

  err "fzf is not installed."
  info "Install optional tools with: unishell tools install fzf"
  return 1
}

_unishell_find_dirs() {
  local base="$1"
  local max_depth="${2:-4}"

  find "$base" \
    -mindepth 1 \
    -maxdepth "$max_depth" \
    \( -name .git -o -name node_modules -o -name .venv -o -name venv \) -prune \
    -o -type d -print 2>/dev/null | sort
}

_unishell_find_files() {
  local base="$1"

  find "$base" \
    \( -name .git -o -name node_modules -o -name .venv -o -name venv \) -prune \
    -o -type f -print 2>/dev/null | sort
}

openproj() {
  _unishell_require_fzf || return 1

  local base="${1:-$WORKSPACE_DIR}"
  if [ ! -d "$base" ]; then
    err "Workspace not found: $base"
    info "Create it with: unishell init"
    return 1
  fi

  local selected=""
  selected="$(_unishell_find_dirs "$base" "${UNISHELL_OPENPROJ_MAX_DEPTH:-4}" | fzf --prompt="Open project > ")" || return 1

  if [ -n "$selected" ]; then
    cd "$selected" || return 1
  fi
}

cdf() {
  _unishell_require_fzf || return 1

  local selected=""
  selected="$(_unishell_find_dirs "." "${UNISHELL_CDF_MAX_DEPTH:-6}" | fzf --prompt="cd into > ")" || return 1

  if [ -n "$selected" ]; then
    cd "$selected" || return 1
  fi
}

editfile() {
  _unishell_require_fzf || return 1

  local editor="${VISUAL:-${EDITOR:-nano}}"
  local selected=""
  selected="$(_unishell_find_files "." | fzf --prompt="Edit file > ")" || return 1

  if [ -n "$selected" ]; then
    "$editor" "$selected"
  fi
}

jump() {
  if ! command -v zoxide >/dev/null 2>&1; then
    err "zoxide is not installed."
    info "Install optional tools with: unishell tools install zoxide"
    return 1
  fi

  local zoxide_cmd="${UNISHELL_ZOXIDE_CMD:-j}"
  if ! command -v "$zoxide_cmd" >/dev/null 2>&1; then
    err "zoxide is installed but its '$zoxide_cmd' shell command is not loaded."
    info "Reload your shell config, then try again."
    return 1
  fi

  "$zoxide_cmd" "$@"
}
