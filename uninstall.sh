#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="$HOME/.unishell"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok() { printf "%b\n" "${GREEN}[OK]${NC}   $1"; }
warn() { printf "%b\n" "${YELLOW}[WARN]${NC} $1"; }
info() { printf "%b\n" "${BLUE}[INFO]${NC} $1"; }
err() { printf "%b\n" "${RED}[ERR]${NC}  $1" >&2; }

clean_shell_config() {
  local shell_config="$1"

  if [ ! -f "$shell_config" ]; then
    warn "Shell config not found: $shell_config"
    return 0
  fi

  sed -i '/# >>> UniShell >>>/,/# <<< UniShell <<</d' "$shell_config"
  sed -i '/export PATH="\$HOME\/.unishell\/bin:\$PATH"/d' "$shell_config"
  sed -i '/source "\$HOME\/.unishell\/core\/loader.sh"/d' "$shell_config"
  ok "Removed UniShell lines from $shell_config"
}

main() {
  info "Uninstalling UniShell"

  if [ -d "$TARGET_DIR" ]; then
    rm -rf -- "$TARGET_DIR"
    ok "Removed $TARGET_DIR"
  else
    warn "$TARGET_DIR is already removed"
  fi

  clean_shell_config "$HOME/.bashrc"
  clean_shell_config "$HOME/.zshrc"

  info "Workspace data was not deleted: $HOME/workspace"
  info "Backups remain at ~/.bashrc.unishell.backup and ~/.zshrc.unishell.backup when present"
  ok "UniShell removed"
}

main "$@"
