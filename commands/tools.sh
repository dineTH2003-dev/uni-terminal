#!/usr/bin/env bash

_unishell_optional_tools() {
  printf "%s\n" "fzf" "zoxide"
}

_unishell_tool_version() {
  local tool="$1"

  case "$tool" in
    fzf|zoxide) "$tool" --version 2>/dev/null | head -n 1 ;;
    *) return 1 ;;
  esac
}

_unishell_optional_tools_status() {
  local tool
  for tool in "$@"; do
    if command -v "$tool" >/dev/null 2>&1; then
      local version=""
      version="$(_unishell_tool_version "$tool" || true)"
      if [ -n "$version" ]; then
        ok "$(printf '%-17s %s' "$tool:" "installed ($version)")"
      else
        ok "$(printf '%-17s %s' "$tool:" "installed")"
      fi
    else
      warn "$(printf '%-17s %s' "$tool:" "not installed")"
    fi
  done
}

_unishell_package_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    printf "%s\n" "apt"
  elif command -v dnf >/dev/null 2>&1; then
    printf "%s\n" "dnf"
  elif command -v pacman >/dev/null 2>&1; then
    printf "%s\n" "pacman"
  elif command -v brew >/dev/null 2>&1; then
    printf "%s\n" "brew"
  elif command -v zypper >/dev/null 2>&1; then
    printf "%s\n" "zypper"
  elif command -v apk >/dev/null 2>&1; then
    printf "%s\n" "apk"
  else
    return 1
  fi
}

_unishell_root_cmd() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    err "This install method needs sudo, but sudo was not found."
    return 1
  fi
}

_unishell_print_optional_tool_instructions() {
  cat <<'EOF'
Install missing optional tools with your package manager:

  Ubuntu/Debian: sudo apt-get install fzf zoxide
  Fedora:        sudo dnf install fzf zoxide
  Arch:          sudo pacman -S fzf zoxide
  macOS:         brew install fzf zoxide

Then reload your shell config:

  source ~/.zshrc
  # or
  source ~/.bashrc
EOF
}

_unishell_install_packages() {
  local manager="$1"
  shift

  case "$manager" in
    apt)
      if ! _unishell_root_cmd apt-get update; then
        warn "apt-get update failed; trying install with existing package lists"
      fi
      _unishell_root_cmd apt-get install -y "$@"
      ;;
    dnf)
      _unishell_root_cmd dnf install -y "$@"
      ;;
    pacman)
      _unishell_root_cmd pacman -Sy --needed "$@"
      ;;
    brew)
      brew install "$@"
      ;;
    zypper)
      _unishell_root_cmd zypper install -y "$@"
      ;;
    apk)
      _unishell_root_cmd apk add "$@"
      ;;
    *)
      return 1
      ;;
  esac
}

unishell_install_tools() {
  local requested=("$@")
  if [ "${#requested[@]}" -eq 0 ]; then
    requested=($(_unishell_optional_tools))
  fi

  local tool
  local missing=()
  for tool in "${requested[@]}"; do
    case "$tool" in
      fzf|zoxide) ;;
      *)
        err "Unsupported optional tool: $tool"
        info "Supported tools: fzf zoxide"
        return 1
        ;;
    esac

    if command -v "$tool" >/dev/null 2>&1; then
      ok "$tool is already installed"
    else
      missing+=("$tool")
    fi
  done

  if [ "${#missing[@]}" -eq 0 ]; then
    ok "All requested optional tools are installed"
    return 0
  fi

  local manager=""
  manager="$(_unishell_package_manager 2>/dev/null)" || {
    warn "No supported package manager was detected."
    _unishell_print_optional_tool_instructions
    return 1
  }

  info "Installing optional tools with $manager: ${missing[*]}"
  _unishell_install_packages "$manager" "${missing[@]}" || {
    warn "Automatic optional tool install failed."
    _unishell_print_optional_tool_instructions
    return 1
  }

  _unishell_optional_tools_status "${missing[@]}"
}

unishell_tools_help() {
  cat <<'EOF'
UniShell optional tools

Usage:
  unishell tools status          Show fzf and zoxide install status
  unishell tools install         Install missing optional tools
  unishell tools install fzf     Install only fzf
  unishell tools install zoxide  Install only zoxide
EOF
}

unishell_tools() {
  local command_name="${1:-status}"
  shift || true

  case "$command_name" in
    status)
      if [ "$#" -eq 0 ]; then
        set -- $(_unishell_optional_tools)
      fi
      _unishell_optional_tools_status "$@"
      ;;
    install)
      unishell_install_tools "$@"
      ;;
    help|-h|--help)
      unishell_tools_help
      ;;
    *)
      err "Unknown tools command: $command_name"
      unishell_tools_help
      return 1
      ;;
  esac
}
