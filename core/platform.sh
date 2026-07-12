#!/usr/bin/env bash
# platform.sh — Cross-platform detection for UniShell
#
# Sets global variables used by every other module to handle platform
# differences gracefully. Sourced once at boot by loader.sh.
#
# Exports:
#   UNISHELL_PLATFORM   — linux | wsl | gitbash | macos | unknown
#   UNISHELL_TMPDIR     — /dev/shm (Linux) or $TMPDIR or /tmp (elsewhere)
#   UNISHELL_HAS_GUI    — 1 if a graphical desktop is available, 0 otherwise
#   UNISHELL_OS_FAMILY  — linux | darwin | windows | unknown

# Skip if already detected (avoid re-running on re-source).
[ "${UNISHELL_PLATFORM_DETECTED:-0}" = "1" ] && return 0 2>/dev/null || true

# ── OS Family ─────────────────────────────────────────────────────────────────

_unishell_detect_os_family() {
  case "$(uname -s 2>/dev/null)" in
    Linux*)   printf "linux"   ;;
    Darwin*)  printf "darwin"  ;;
    MINGW*|MSYS*|CYGWIN*) printf "windows" ;;
    *)        printf "unknown" ;;
  esac
}

# ── Platform (more specific than OS family) ───────────────────────────────────

_unishell_detect_platform() {
  local os_family="$1"

  case "$os_family" in
    linux)
      # Check if we're inside WSL (Windows Subsystem for Linux).
      if [ -f /proc/version ] && grep -qi 'microsoft\|wsl' /proc/version 2>/dev/null; then
        printf "wsl"
      else
        printf "linux"
      fi
      ;;
    darwin)
      printf "macos"
      ;;
    windows)
      # MSYS2/MinGW/Cygwin = Git Bash environment on Windows.
      printf "gitbash"
      ;;
    *)
      printf "unknown"
      ;;
  esac
}

# ── GUI Detection ─────────────────────────────────────────────────────────────

_unishell_detect_gui() {
  local platform="$1"

  case "$platform" in
    linux)
      # Check for a running display server.
      if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
        printf "1"
      else
        printf "0"
      fi
      ;;
    wsl)
      # WSLg provides GUI support — check for DISPLAY or WAYLAND_DISPLAY.
      if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
        printf "1"
      else
        printf "0"
      fi
      ;;
    macos)
      # macOS always has a GUI unless running in headless/SSH mode.
      if [ -n "${SSH_CONNECTION:-}" ] && [ -z "${DISPLAY:-}" ]; then
        printf "0"
      else
        printf "1"
      fi
      ;;
    gitbash)
      # Git Bash runs inside Windows which always has a GUI.
      printf "1"
      ;;
    *)
      printf "0"
      ;;
  esac
}

# ── Temp Directory ────────────────────────────────────────────────────────────

_unishell_detect_tmpdir() {
  local platform="$1"

  # /dev/shm is a Linux-specific RAM-backed tmpfs — fastest for temp files.
  # On other platforms, fall back to $TMPDIR or /tmp.
  case "$platform" in
    linux|wsl)
      if [ -d /dev/shm ] && [ -w /dev/shm ]; then
        printf "/dev/shm"
      else
        printf "%s" "${TMPDIR:-/tmp}"
      fi
      ;;
    *)
      printf "%s" "${TMPDIR:-/tmp}"
      ;;
  esac
}

# ── Package Manager ───────────────────────────────────────────────────────────

_unishell_detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then printf "apt"
  elif command -v dnf    >/dev/null 2>&1; then printf "dnf"
  elif command -v pacman >/dev/null 2>&1; then printf "pacman"
  elif command -v brew   >/dev/null 2>&1; then printf "brew"
  elif command -v apk    >/dev/null 2>&1; then printf "apk"
  elif command -v zypper >/dev/null 2>&1; then printf "zypper"
  else printf "none"
  fi
}

# ── Run Detection ─────────────────────────────────────────────────────────────

UNISHELL_OS_FAMILY="$(_unishell_detect_os_family)"
UNISHELL_PLATFORM="$(_unishell_detect_platform "$UNISHELL_OS_FAMILY")"
UNISHELL_HAS_GUI="$(_unishell_detect_gui "$UNISHELL_PLATFORM")"
UNISHELL_TMPDIR="$(_unishell_detect_tmpdir "$UNISHELL_PLATFORM")"
UNISHELL_PKG_MANAGER="$(_unishell_detect_pkg_manager)"

export UNISHELL_PLATFORM UNISHELL_OS_FAMILY UNISHELL_HAS_GUI UNISHELL_TMPDIR UNISHELL_PKG_MANAGER

UNISHELL_PLATFORM_DETECTED=1

# Clean up detection functions — they're only needed once.
unset -f _unishell_detect_os_family _unishell_detect_platform \
         _unishell_detect_gui _unishell_detect_tmpdir _unishell_detect_pkg_manager
