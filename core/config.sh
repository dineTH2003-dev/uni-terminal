#!/usr/bin/env bash

UNISHELL_CONFIG_LOADED=1

: "${UNISHELL_HOME:=$HOME/.unishell}"
UNISHELL_VERSION="3.0.0"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok() { printf "%b\n" "${GREEN}[OK]${NC}   $1"; }
warn() { printf "%b\n" "${YELLOW}[WARN]${NC} $1"; }
info() { printf "%b\n" "${BLUE}[INFO]${NC} $1"; }
err() { printf "%b\n" "${RED}[ERR]${NC}  $1" >&2; }

# Prompt user for input
unishell_ask() {
  local prompt="$1"
  read -rp "$prompt " answer
  echo "$answer"
}

# Yes/No confirmation (returns 0 for yes)
unishell_confirm() {
  local prompt="$1 (y/N): "
  read -rp "$prompt" answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

unishell_shell_name() {
  basename "${SHELL:-unknown}"
}

unishell_shell_config() {
  local shell_name
  shell_name="$(unishell_shell_name)"

  case "$shell_name" in
    zsh) printf "%s\n" "$HOME/.zshrc" ;;
    bash) printf "%s\n" "$HOME/.bashrc" ;;
    *) printf "%s\n" "$HOME/.bashrc" ;;
  esac
}

# Lazy-load engine: registers self-replacing stub functions for a module.
# Usage: _unishell_lazy <module_basename> <fn1> [fn2 ...]
# On first call of any registered fn, sources the real module then re-invokes.
_unishell_lazy() {
  local module="$1"; shift
  local fn
  for fn in "$@"; do
    eval "
    ${fn}() {
      unset -f '${fn}' 2>/dev/null || true
      if [ -f \"\$UNISHELL_HOME/commands/${module}.sh\" ]; then
        . \"\$UNISHELL_HOME/commands/${module}.sh\"
      else
        printf '%b\\n' \"\033[0;31m[ERR]\033[0m  Module not found: commands/${module}.sh\" >&2
        return 1
      fi
      '${fn}' \"\$@\"
    }
    "
  done
}

unishell_session_off() {
  local unishell_bin="$UNISHELL_HOME/bin"
  local shell_config
  local path_value

  shell_config="$(unishell_shell_config)"
  path_value=":${PATH:-}:"
  path_value="${path_value//:$unishell_bin:/:}"
  path_value="${path_value#:}"
  path_value="${path_value%:}"
  PATH="$path_value"
  export PATH

  unalias uniexit 2>/dev/null || true

  if command -v _unishell_predict_disable_hooks >/dev/null 2>&1; then
    _unishell_predict_disable_hooks 2>/dev/null || true
  fi

  local fn
  for fn in \
    unishell_help unishell_shell_name \
    unishell_shell_config _unishell_lazy \
    ok warn info err unishell_ask \
    unishell_confirm unishell_session_off unishell uniexit \
    predict TRAPERR _unishell_predict_debug _unishell_predict_hook \
    _unishell_predict_enable_hooks _unishell_predict_disable_hooks \
    _unishell_predict_match \
    drift _unishell_drift_hook \
    ghostsave _unishell_ghost_tick \
    context _unishell_context_hook \
    broadcast _unishell_broadcast_server \
    showme _showme_detect_terminal _showme_check_deps _showme_has \
    _showme_open_window _showme_write_engine _showme_cleanup; do
    unset -f "$fn" 2>/dev/null || true
    # BUG-9 FIX: unfunction is Zsh-only; skip in Bash.
    [ -n "${ZSH_VERSION:-}" ] && unfunction "$fn" 2>/dev/null || true
  done

  unset UNISHELL_HOME UNISHELL_VERSION UNISHELL_CONFIG_LOADED UNISHELL_LOADER_LOADED \
    UNISHELL_LAST_DIR UNISHELL_CONTEXT_DIR UNISHELL_GHOST_LAST UNISHELL_PREDICT_ENABLED \
    UNISHELL_PLATFORM UNISHELL_OS_FAMILY UNISHELL_HAS_GUI UNISHELL_TMPDIR \
    UNISHELL_PKG_MANAGER UNISHELL_PLATFORM_DETECTED
  printf "UniShell disabled for this shell session. Run 'source %s' to load it again.\n" "$shell_config"
}

unishell() {
  local command_name="${1:-help}"

  case "$command_name" in
    off|exit|disable)
      shift || true
      unishell_session_off "$@"
      ;;
    *)
      "$UNISHELL_HOME/bin/unishell" "$@"
      ;;
  esac
}

uniexit() {
  unishell off "$@"
}

unishell_help() {
  cat <<'EOF'
UniShell v3.0.0 — Developer Intelligence Toolkit

Usage:
  unishell help             Show this help
  unishell version          Print version
  unishell off              Disable UniShell in this shell session

Commands:
  predict [on|off|learn]    Diagnose and fix failed commands automatically
  drift [snapshot|diff|reset|list]  Detect environment drift that breaks projects
  ghostsave [enable|disable|restore|squash|status]  Invisible auto-save shadow commits
  context [replay|mark-setup|search|projects]  Per-project command memory
  broadcast [start|stop]    Stream your terminal read-only to a browser on LAN
  showme [stop|--inline]    Show commands behind every GUI action in real time

Session:
  uniexit                   Disable UniShell in this shell session

Cross-platform: Linux ● macOS ● WSL2 ● Git Bash
EOF
}
