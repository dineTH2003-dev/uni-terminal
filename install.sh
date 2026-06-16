#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
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

INSTALL_OPTIONAL_TOOLS="prompt"

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --with-tools              Install missing optional tools: fzf and zoxide
  --install-optional-tools  Same as --with-tools
  --no-optional-tools       Do not prompt for optional tool installation
  -h, --help                Show this help
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --with-tools|--install-optional-tools)
        INSTALL_OPTIONAL_TOOLS="yes"
        ;;
      --no-optional-tools)
        INSTALL_OPTIONAL_TOOLS="no"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        err "Unknown option: $1"
        usage >&2
        exit 1
        ;;
    esac
    shift
  done
}

detect_shell_config() {
  local shell_name
  shell_name="$(basename "${SHELL:-}")"

  case "$shell_name" in
    zsh) printf "%s\n" "$HOME/.zshrc" ;;
    bash) printf "%s\n" "$HOME/.bashrc" ;;
    *)
      warn "Unsupported shell '$shell_name'. Using $HOME/.bashrc." >&2
      printf "%s\n" "$HOME/.bashrc"
      ;;
  esac
}

copy_installation() {
  mkdir -p "$TARGET_DIR"

  local item
  for item in bin core commands integrations templates docs tests README.md LICENSE CONTRIBUTING.md install.sh uninstall.sh; do
    if [ -e "$REPO_ROOT/$item" ]; then
      cp -R "$REPO_ROOT/$item" "$TARGET_DIR/"
    fi
  done
}

backup_shell_config() {
  local shell_config="$1"
  local backup_file="${shell_config}.unishell.backup"

  mkdir -p "$(dirname "$shell_config")"
  touch "$shell_config"

  if [ -f "$backup_file" ]; then
    warn "Shell config backup already exists: $backup_file"
  else
    cp "$shell_config" "$backup_file"
    ok "Backed up shell config to $backup_file"
  fi
}

missing_optional_tools() {
  local tool
  for tool in fzf zoxide; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      printf "%s\n" "$tool"
    fi
  done
}

maybe_install_optional_tools() {
  local missing=()
  local tool
  while IFS= read -r tool; do
    [ -n "$tool" ] && missing+=("$tool")
  done < <(missing_optional_tools)

  if [ "${#missing[@]}" -eq 0 ]; then
    ok "Optional tools already installed: fzf zoxide"
    return 0
  fi

  case "$INSTALL_OPTIONAL_TOOLS" in
    yes)
      "$TARGET_DIR/bin/unishell" tools install "${missing[@]}" || warn "Optional tool installation did not complete"
      ;;
    no)
      warn "Optional tools missing: ${missing[*]}"
      info "Install later with: unishell tools install"
      ;;
    prompt)
      if [ -t 0 ]; then
        warn "Optional tools missing: ${missing[*]}"
        printf "Install optional UniShell tools now? (y/N): "
        local confirm="n"
        read -r confirm
        case "$confirm" in
          y|Y|yes|YES)
            "$TARGET_DIR/bin/unishell" tools install "${missing[@]}" || warn "Optional tool installation did not complete"
            ;;
          *)
            info "Install later with: unishell tools install"
            ;;
        esac
      else
        warn "Optional tools missing: ${missing[*]}"
        info "Install later with: unishell tools install"
      fi
      ;;
  esac
}

ensure_shell_config() {
  local shell_config="$1"
  local path_line='export PATH="$HOME/.unishell/bin:$PATH"'
  local source_line='source "$HOME/.unishell/core/loader.sh"'

  if grep -Fq "$source_line" "$shell_config" && grep -Fq "$path_line" "$shell_config"; then
    ok "Shell config already contains UniShell lines"
    return 0
  fi

  cat >> "$shell_config" <<'EOF'

# >>> UniShell >>>
export PATH="$HOME/.unishell/bin:$PATH"
source "$HOME/.unishell/core/loader.sh"
# <<< UniShell <<<
EOF
  ok "Added UniShell to $shell_config"
}

main() {
  parse_args "$@"

  info "Installing UniShell"

  local shell_config
  shell_config="$(detect_shell_config)"
  info "Detected shell config: $shell_config"

  local should_copy="yes"
  if [ -e "$TARGET_DIR" ]; then
    warn "$TARGET_DIR already exists."

    local confirm="n"
    if [ -t 0 ]; then
      printf "Overwrite existing UniShell files? (y/N): "
      read -r confirm
    else
      warn "Non-interactive install detected; refreshing existing installation."
      confirm="y"
    fi

    case "$confirm" in
      y|Y|yes|YES)
        local backup_dir
        backup_dir="$HOME/.unishell.backup.$(date +%Y%m%d%H%M%S)"
        mv "$TARGET_DIR" "$backup_dir"
        ok "Backed up existing installation to $backup_dir"
        ;;
      *)
        warn "Keeping existing $TARGET_DIR"
        should_copy="no"
        ;;
    esac
  fi

  backup_shell_config "$shell_config"

  if [ "$should_copy" = "yes" ]; then
    copy_installation
    ok "Copied UniShell files to $TARGET_DIR"
  else
    warn "Skipped file copy"
  fi

  chmod +x "$TARGET_DIR/bin/unishell" "$TARGET_DIR/install.sh" "$TARGET_DIR/uninstall.sh" "$TARGET_DIR/tests/test-install.sh" 2>/dev/null || true
  ok "Set executable permissions"

  if [ "$should_copy" = "yes" ]; then
    maybe_install_optional_tools
  else
    warn "Skipped optional tool setup because UniShell files were not refreshed"
    info "Run ./install.sh again and allow refresh, or install tools manually"
  fi

  ensure_shell_config "$shell_config"

  "$TARGET_DIR/bin/unishell" init

  ok "UniShell installed"
  info "Reload your shell with: source $shell_config"
  info "Then run: unishell doctor"
}

main "$@"
