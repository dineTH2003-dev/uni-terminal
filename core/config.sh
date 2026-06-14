#!/usr/bin/env bash

if [ -n "${UNISHELL_CONFIG_LOADED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
UNISHELL_CONFIG_LOADED=1

: "${UNISHELL_HOME:=$HOME/.unishell}"
: "${WORKSPACE_DIR:=$HOME/workspace}"
UNISHELL_VERSION="1.0.0"

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

unishell_help() {
  cat <<'EOF'
UniShell v1.0.0

Usage:
  unishell init             Create ~/workspace folders
  unishell doctor           Check UniShell and common tools
  unishell help             Show this help
  unishell version          Print version

Workspace:
  ws                        cd ~/workspace
  uni                       cd ~/workspace/university
  proj                      cd ~/workspace/projects
  devops                    cd ~/workspace/devops
  learn                     cd ~/workspace/learning
  scripts                   cd ~/workspace/scripts

Generators:
  mkassign NAME             Create a university assignment folder
  mkproject NAME --basic    Create a basic project
  mkproject NAME --python   Create a Python project
  mkproject NAME --node     Create a Node.js project

Git:
  gstatus                   Short git status
  gsave "message"           Add all files and commit
  gpush                     Push to the current remote
  glog                      Last 20 commits as a graph
  gnew branch-name          Create and switch to a branch
  gundo                     Soft reset the last commit

System:
  sysinfo                   OS, CPU, RAM, and uptime
  ports                     Listening TCP/UDP ports
  myip                      Local and public IP
  diskcheck                 Disk usage
  memcheck                  Memory usage
  service-check NAME        systemctl status for a service
  docker-clean              Remove stopped containers and dangling images
EOF
}
