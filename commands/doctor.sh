#!/usr/bin/env bash

_unishell_tool_status() {
  local label="$1"
  local command_name="$2"
  local version_arg="${3:-}"

  if command -v "$command_name" >/dev/null 2>&1; then
    local version=""
    if [ -n "$version_arg" ]; then
      version="$("$command_name" "$version_arg" 2>/dev/null | head -n 1 || true)"
    fi

    if [ -n "$version" ]; then
      ok "$(printf '%-17s %s' "$label:" "installed ($version)")"
    else
      ok "$(printf '%-17s %s' "$label:" "installed")"
    fi
  else
    warn "$(printf '%-17s %s' "$label:" "not installed")"
  fi
}

unishell_doctor() {
  printf "%b\n" "${BOLD}UniShell Doctor v$UNISHELL_VERSION${NC}"
  printf "%s\n" "-------------------------------"

  local shell_name
  shell_name="$(unishell_shell_name)"
  ok "$(printf '%-17s %s' "Shell:" "$shell_name")"

  _unishell_tool_status "Git" "git" "--version"
  _unishell_tool_status "Python3" "python3" "--version"
  _unishell_tool_status "Docker" "docker" "--version"
  _unishell_tool_status "Node.js" "node" "--version"
  _unishell_tool_status "fzf" "fzf" "--version"
  if [ "${UNISHELL_FZF_ENABLED:-0}" = "1" ]; then
    ok "$(printf '%-17s %s' "fzf integration:" "enabled")"
  elif [ "${UNISHELL_FZF_AVAILABLE:-0}" = "1" ]; then
    warn "$(printf '%-17s %s' "fzf integration:" "available; reload an interactive shell")"
  else
    warn "$(printf '%-17s %s' "fzf integration:" "disabled")"
  fi

  _unishell_tool_status "zoxide" "zoxide" "--version"
  if [ "${UNISHELL_ZOXIDE_ENABLED:-0}" = "1" ]; then
    ok "$(printf '%-17s %s' "zoxide integration:" "enabled as ${UNISHELL_ZOXIDE_CMD:-j}")"
  elif [ "${UNISHELL_ZOXIDE_AVAILABLE:-0}" = "1" ]; then
    warn "$(printf '%-17s %s' "zoxide integration:" "available; reload an interactive shell")"
  else
    warn "$(printf '%-17s %s' "zoxide integration:" "disabled")"
  fi

  if [ -d "$UNISHELL_HOME" ]; then
    ok "$(printf '%-17s %s' "UniShell:" "$UNISHELL_HOME")"
  else
    warn "$(printf '%-17s %s' "UniShell:" "not installed at $UNISHELL_HOME")"
  fi

  if command -v mkproject >/dev/null 2>&1 && command -v mkassign >/dev/null 2>&1; then
    ok "$(printf '%-17s %s' "Loaded:" "yes")"
  else
    warn "$(printf '%-17s %s' "Loaded:" "loader not active")"
  fi

  if [ -d "$WORKSPACE_DIR" ]; then
    ok "$(printf '%-17s %s' "Workspace:" "$WORKSPACE_DIR exists")"
  else
    warn "$(printf '%-17s %s' "Workspace:" "$WORKSPACE_DIR missing")"
  fi

  local shell_config
  shell_config="$(unishell_shell_config)"
  if [ -f "$shell_config" ] && grep -Fq 'source "$HOME/.unishell/core/loader.sh"' "$shell_config"; then
    ok "$(printf '%-17s %s' "Source line:" "present in $shell_config")"
  else
    warn "$(printf '%-17s %s' "Source line:" "missing from $shell_config")"
  fi

  if [ -f "${shell_config}.unishell.backup" ]; then
    info "$(printf '%-17s %s' "Config backup:" "${shell_config}.unishell.backup")"
  else
    info "$(printf '%-17s %s' "Config backup:" "not found")"
  fi

  printf "%s\n" "-------------------------------"
  printf "Run 'unishell help' for available commands.\n"
}
