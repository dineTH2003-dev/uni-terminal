#!/usr/bin/env bash

UNISHELL_CONFIG_LOADED=1

: "${UNISHELL_HOME:=$HOME/.unishell}"
: "${WORKSPACE_DIR:=$HOME/workspace}"
: "${UNISHELL_ENABLE_FZF:=1}"
: "${UNISHELL_ENABLE_ZOXIDE:=1}"
: "${UNISHELL_ZOXIDE_CMD:=j}"
UNISHELL_VERSION="2.0.0"

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

unishell_valid_name() {
  local name="$1"
  [ -n "$name" ] && [[ "$name" != *[^A-Za-z0-9._-]* ]]
}

# Lazy-load engine: registers self-replacing stub functions for a module.
# Usage: _unishell_lazy <module_basename> <fn1> [fn2 ...]
# On first call of any registered fn, sources the real module then re-invokes.
_unishell_lazy() {
  local module="$1"; shift
  local fn
  for fn in "$@"; do
    # Use printf+eval to avoid issues with function names containing hyphens
    eval "
    ${fn}() {
      unset -f '${fn}' 2>/dev/null || true
      if [ -f \"\$UNISHELL_HOME/commands/${module}.sh\" ]; then
        . \"\$UNISHELL_HOME/commands/${module}.sh\"
      else
        printf '%b\\n' \"\\033[0;31m[ERR]\\033[0m  Module not found: commands/${module}.sh\" >&2
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

  unalias ws uni proj devops learn scripts uniexit 2>/dev/null || true

  local fn
  for fn in \
    unishell_init unishell_doctor unishell_help unishell_shell_name \
    unishell_shell_config unishell_valid_name _unishell_lazy \
    mkassign mkproject whatshere onboard \
    openproj cdf editfile jump _unishell_require_fzf _unishell_find_dirs \
    _unishell_find_files unishell_tools unishell_tools_help \
    unishell_install_tools _unishell_optional_tools \
    _unishell_optional_tools_status _unishell_tool_version \
    _unishell_package_manager _unishell_root_cmd \
    _unishell_print_optional_tool_instructions _unishell_install_packages \
    gstatus gsave gpush glog gnew gundo sysinfo ports myip diskcheck \
    memcheck service-check docker-clean _unishell_require_git_repo \
    killport _unishell_tool_status ok warn info err unishell_ask \
    unishell_confirm unishell_session_off unishell uniexit \
    autopsy _unishell_autopsy_hook _unishell_autopsy_match \
    drift _unishell_drift_hook \
    ghostsave _unishell_ghost_tick \
    context _unishell_context_hook \
    broadcast _unishell_broadcast_server; do
    unset -f "$fn" 2>/dev/null || true
    unfunction "$fn" 2>/dev/null || true
  done

  if [ "${UNISHELL_ZOXIDE_ENABLED:-0}" = "1" ]; then
    local zoxide_cmd="${UNISHELL_ZOXIDE_CMD:-j}"
    unset -f "$zoxide_cmd" "${zoxide_cmd}i" __zoxide_z __zoxide_zi __zoxide_hook __zoxide_pwd 2>/dev/null || true
    unfunction "$zoxide_cmd" "${zoxide_cmd}i" __zoxide_z __zoxide_zi __zoxide_hook __zoxide_pwd 2>/dev/null || true
  fi

  unset UNISHELL_HOME UNISHELL_VERSION UNISHELL_CONFIG_LOADED UNISHELL_LOADER_LOADED \
    UNISHELL_ENABLE_FZF UNISHELL_ENABLE_ZOXIDE UNISHELL_ZOXIDE_CMD \
    UNISHELL_FZF_AVAILABLE UNISHELL_FZF_ENABLED \
    UNISHELL_ZOXIDE_AVAILABLE UNISHELL_ZOXIDE_ENABLED \
    UNISHELL_LAST_DIR UNISHELL_CONTEXT_DIR UNISHELL_GHOST_LAST UNISHELL_AUTOPSY_ENABLED
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
UniShell v2.0.0

Usage:
  unishell init             Create ~/workspace folders
  unishell doctor           Check UniShell and common tools
  unishell tools status     Check optional fzf and zoxide tools
  unishell tools install    Install missing optional fzf/zoxide tools
  unishell off              Disable UniShell in this shell session
  unishell help             Show this help
  unishell version          Print version

Session:
  uniexit                   Disable UniShell in this shell session

Workspace:
  ws                        cd ~/workspace
  uni                       cd ~/workspace/university
  proj                      cd ~/workspace/projects
  devops                    cd ~/workspace/devops
  learn                     cd ~/workspace/learning
  scripts                   cd ~/workspace/scripts

Navigation:
  openproj [DIR]             Fuzzy open a project/workspace folder
  cdf                        Fuzzy cd into a folder below current directory
  editfile                   Fuzzy select a file and open it in $EDITOR
  j NAME                     Smart jump with zoxide when installed
  ji                         Interactive zoxide jump when installed
  jump NAME                  UniShell wrapper around the zoxide jump command

Generators:
  mkassign NAME             Create a university assignment folder
  mkproject NAME --basic    Create a basic project
  mkproject NAME --python   Create a Python project
  mkproject NAME --node     Create a Node.js project
  whatshere                 Fingerprint the current project directory
  onboard REPO_URL          Clone and automatically set up a project

Git:
  gstatus                   Short git status
  gsave "message"           Add all files and commit
  gpush                     Push (guards against pushing to main/master)
  glog                      Last 20 commits as a graph
  gnew branch-name          Create and switch to a branch
  gundo                     Soft reset the last commit
  ghostsave [squash|restore|status|enable|disable]  Invisible auto-save shadow commits

System:
  sysinfo                   OS, CPU, RAM, and uptime
  ports                     Listening TCP/UDP ports
  killport PORT             Find and kill the process on a port
  myip                      Local and public IP
  diskcheck                 Disk usage
  memcheck                  Memory usage
  service-check NAME        systemctl status for a service
  docker-clean              Remove stopped containers and dangling images

Intelligence (v2):
  autopsy [on|off|learn]    Diagnose and fix failed commands automatically
  drift [snapshot|check|diff|reset]  Detect environment changes that break projects
  context [log|replay|mark-setup|clear]  Per-project command memory
  broadcast [start|stop]    Stream your terminal read-only to a browser on LAN
EOF
}
