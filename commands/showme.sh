#!/usr/bin/env bash
# showme.sh — GUI Transparency Engine
#
# Opens a new terminal window that shows the equivalent shell commands
# running behind every action the user performs in their desktop GUI.
#
# Click "New Folder" in Files   → terminal shows: mkdir "/home/user/Desktop/NewFolder"
# Connect to WiFi                → terminal shows: nmcli device wifi connect "Network"
# Install app via Software Center → terminal shows: sudo apt-get install vlc
#
# Uses three monitoring layers:
#   1. inotifywait  — filesystem create/delete/rename/move
#   2. dbus-monitor — network, USB, Bluetooth, brightness, volume
#   3. journalctl   — package installs, service starts/stops
#
# Zero internet. Zero daemon. Pure Bash + standard Linux tools.

# ── Dependency helpers ────────────────────────────────────────────────────────

_showme_has() { command -v "$1" >/dev/null 2>&1; }

_showme_check_deps() {
  local ok=1
  if ! _showme_has inotifywait; then
    warn "inotify-tools is not installed (needed for filesystem monitoring)."
    local mgr
    mgr=$(_unishell_package_manager 2>/dev/null || echo "")
    if [ -n "$mgr" ]; then
      printf "%b" "  Install it now? (y/N): "
      local ans; read -r ans
      case "$ans" in
        y|Y|yes|YES)
          case "$mgr" in
            apt)    _unishell_root_cmd apt-get install -y inotify-tools ;;
            dnf)    _unishell_root_cmd dnf install -y inotify-tools ;;
            pacman) _unishell_root_cmd pacman -S --needed inotify-tools ;;
            *)      warn "Install manually: your-package-manager install inotify-tools" ; ok=0 ;;
          esac
          ;;
        *) ok=0 ;;
      esac
    else
      warn "Install inotify-tools with your package manager, then re-run showme."
      ok=0
    fi
  fi

  if ! _showme_has dbus-monitor; then
    warn "dbus-monitor not found — D-Bus layer (network/USB) will be skipped."
    info "Install: sudo apt install dbus (usually pre-installed on GNOME/KDE)"
  fi

  if ! _showme_has journalctl; then
    warn "journalctl not found — system journal layer will be skipped."
  fi

  [ "$ok" -eq 1 ]
}

# ── Terminal emulator detection ───────────────────────────────────────────────

_showme_detect_terminal() {
  # Try terminals in order of preference.
  local t
  for t in gnome-terminal konsole xfce4-terminal mate-terminal lxterminal \
            tilix kitty alacritty wezterm xterm; do
    _showme_has "$t" && printf "%s\n" "$t" && return
  done
  return 1
}

# Build the terminal launch command for a given script.
_showme_open_window() {
  local script="$1"
  local terminal
  terminal=$(_showme_detect_terminal) || {
    warn "No GUI terminal emulator found. Running inline instead."
    bash "$script"
    return
  }

  case "$terminal" in
    gnome-terminal)  gnome-terminal --title="UniShell showme" -- bash "$script" ;;
    konsole)         konsole --title "UniShell showme" -e bash "$script" ;;
    xfce4-terminal)  xfce4-terminal --title="UniShell showme" -e "bash $script" ;;
    mate-terminal)   mate-terminal --title="UniShell showme" -e "bash $script" ;;
    lxterminal)      lxterminal --title="UniShell showme" -e "bash $script" ;;
    tilix)           tilix -e "bash $script" ;;
    kitty)           kitty --title "UniShell showme" bash "$script" ;;
    alacritty)       alacritty --title "UniShell showme" -e bash "$script" ;;
    wezterm)         wezterm start -- bash "$script" ;;
    xterm)           xterm -title "UniShell showme" -e bash "$script" ;;
  esac
}

# ── Engine script generator ───────────────────────────────────────────────────
# Writes a self-contained monitoring script to /dev/shm and returns the path.
# The engine is self-contained — it does NOT need UniShell to be sourced.

_showme_write_engine() {
  local watch_dirs_args="$1"   # space-separated list of dirs to watch
  local layers="$2"            # comma-separated: fs,dbus,journal
  local engine="/dev/shm/unishell_showme_engine_$$.sh"

  cat >"$engine" <<ENGINEEOF
#!/usr/bin/env bash
# UniShell showme engine — auto-generated, self-contained

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# ── PID tracking for clean shutdown ──────────────────────────────────────────
PIDS=()
_showme_cleanup() {
  printf "\n\${DIM}  Stopping showme...\${NC}\n"
  for pid in "\${PIDS[@]}"; do
    kill "\$pid" 2>/dev/null || true
  done
  # Remove this engine script.
  rm -f "$engine"
  exit 0
}
trap '_showme_cleanup' INT TERM EXIT

# ── Render: timestamp + color-coded source tag + command ─────────────────────
_render() {
  local src="\$1" color="\$2" cmd="\$3"
  printf "  \${DIM}%s\${NC}  \${color}%-10s\${NC}  \${BOLD}%s\${NC}\n" \
    "\$(date '+%H:%M:%S')" "[\$src]" "\$cmd"
}

# ── Noise filter ─────────────────────────────────────────────────────────────
_should_skip() {
  local path="\$1"
  case "\$path" in
    */.cache/*|*/.mozilla/*|*/.config/pulse/*|*/.thumbnails/*|\
    *Trash*|*recently-used*|*/.git/*|*/node_modules/*|*/__pycache__/*|\
    */.local/share/gvfs-metadata/*|*~|*.swp|*.swx|*/tmp/*|*/.config/chromium/*)
      return 0 ;;
  esac
  return 1
}

# ── Clear screen and print header ────────────────────────────────────────────
clear
printf "\n"
printf "  \${BOLD}\${CYAN}◉  UniShell showme\${NC}   GUI Transparency Mode\n"
printf "  \${DIM}─────────────────────────────────────────────────────────\${NC}\n"
printf "  Watching: \${GREEN}${watch_dirs_args}\${NC}\n"
printf "\n"
printf "  \${GREEN}●\${NC} filesystem  "
printf "\${BLUE}●\${NC} network/hardware  "
printf "\${YELLOW}●\${NC} packages/services\n"
printf "  \${DIM}─────────────────────────────────────────────────────────\${NC}\n"
printf "\n"
printf "  \${CYAN}💡 Try it:\${NC} Open your file manager and create a new folder\n"
printf "\n"

# ── Layer 1: Filesystem (inotifywait) ─────────────────────────────────────────
_run_fs_layer() {
  command -v inotifywait >/dev/null 2>&1 || return

  # Collect existing watch dirs from the arg string.
  local dirs=()
  for d in ${watch_dirs_args}; do
    [ -d "\$d" ] && dirs+=("\$d")
  done
  [ "\${#dirs[@]}" -eq 0 ] && return

  local last_moved_from=""

  inotifywait -m -r \\
    --format '%w|%f|%e' \\
    --exclude '(\\.cache|\\.mozilla|\\.config/pulse|\\.thumbnails|Trash|recently-used|\\.git/|node_modules|__pycache__|gvfs-metadata)' \\
    "\${dirs[@]}" 2>/dev/null | \\
  while IFS='|' read -r dir file event; do
    local full="\${dir}\${file}"
    # Replace home prefix with ~ for readability.
    local disp="\${full/#\$HOME/~}"

    # Skip noise.
    _should_skip "\$full" && continue

    case "\$event" in
      *CREATE,ISDIR*|*ISDIR,CREATE*)
        _render "Files" "\${GREEN}" "mkdir \"\${disp}\""
        last_moved_from=""
        ;;
      *CREATE*)
        _render "Files" "\${GREEN}" "touch \"\${disp}\""
        last_moved_from=""
        ;;
      *MOVED_FROM*)
        last_moved_from="\$disp"
        ;;
      *MOVED_TO*|*MOVED_FROM,MOVED_TO*)
        if [ -n "\$last_moved_from" ]; then
          _render "Files" "\${CYAN}" "mv \"\${last_moved_from}\" \"\${disp}\""
          last_moved_from=""
        else
          _render "Files" "\${CYAN}" "mv <source> \"\${disp}\""
        fi
        ;;
      *DELETE,ISDIR*|*ISDIR,DELETE*)
        _render "Files" "\${RED}" "rmdir \"\${disp}\""
        last_moved_from=""
        ;;
      *DELETE*)
        _render "Files" "\${RED}" "rm \"\${disp}\""
        last_moved_from=""
        ;;
      *CLOSE_WRITE*)
        # Only show saves for files in project/doc dirs, not every temp file.
        case "\$full" in
          *.txt|*.md|*.py|*.js|*.ts|*.sh|*.json|*.yaml|*.yml|*.toml|*.conf|*.cfg|\
          *.html|*.css|*.rs|*.go|*.c|*.cpp|*.h|*.java|*.odt|*.ods|*.odp)
            _render "Files" "\${DIM}\${NC}" "# Saved: \"\${disp}\""
            ;;
        esac
        ;;
      *ATTRIB*)
        # Detect chmod — permission change.
        local perms=""
        perms="\$(stat -c '%a' "\$full" 2>/dev/null || echo "")"
        [ -n "\$perms" ] && _render "Files" "\${MAGENTA}" "chmod \$perms \"\${disp}\""
        ;;
    esac
  done
}

# ── Layer 2: D-Bus (dbus-monitor) ─────────────────────────────────────────────
_run_dbus_layer() {
  command -v dbus-monitor >/dev/null 2>&1 || return

  # Monitor session bus (user-level app events).
  (
    dbus-monitor --session 2>/dev/null | awk '
    # NetworkManager via session bus (nm-applet, GNOME network indicator)
    /org\.freedesktop\.NetworkManager/ { nm=1 }
    nm && /method call/ && /ActivateConnection/ {
      print "Network\t\033[0;34m\tnmcli device wifi connect \"<network>\""
      nm=0
    }
    nm && /method call/ && /DeactivateConnection/ {
      print "Network\t\033[0;34m\tnmcli device disconnect wlan0"
      nm=0
    }

    # UDisks2 (USB mount/unmount via file manager)
    /org\.freedesktop\.UDisks2/ { ud=1; udpath="" }
    ud && /object path/ { match($0,/"([^"]+)"/,a); udpath=a[1] }
    ud && /method call/ && /Mount/ {
      print "Drives\t\033[0;34m\tudisksctl mount -b /dev/sdX"
      ud=0
    }
    ud && /method call/ && /Unmount/ {
      print "Drives\t\033[0;34m\tudisksctl unmount -b /dev/sdX"
      ud=0
    }
    ud && /method call/ && /PowerOff/ {
      print "Drives\t\033[0;34m\tudisksctl power-off -b /dev/sdX"
      ud=0
    }

    # GNOME Settings / Mutter (screen brightness)
    /org\.gnome\.Mutter\.DisplayConfig/ { mc=1 }
    mc && /method call/ && /ApplyMonitorsConfig/ {
      print "Display\t\033[0;34m\txrandr --auto  # display layout changed"
      mc=0
    }

    # Bluetooth
    /org\.bluez/ { bt=1 }
    bt && /method call/ && /Connect/ {
      print "Bluetooth\t\033[0;34m\tbluetoothctl connect <device>"
      bt=0
    }
    bt && /method call/ && /Disconnect/ {
      print "Bluetooth\t\033[0;34m\tbluetoothctl disconnect <device>"
      bt=0
    }
    bt && /method call/ && /Pair/ {
      print "Bluetooth\t\033[0;34m\tbluetoothctl pair <device>"
      bt=0
    }
    ' | while IFS=$'\t' read -r src color cmd; do
      _render "\$src" "\$color" "\$cmd"
    done
  ) &
  PIDS+=(\$!)

  # Monitor system bus (hardware/power events).
  (
    dbus-monitor --system 2>/dev/null | awk '
    # PackageKit (Software Center installs/removes)
    /org\.freedesktop\.PackageKit/ { pk=1 }
    pk && /method call/ && /InstallPackages/ {
      print "Software\t\033[1;33m\tsudo apt-get install <package>"
      pk=0
    }
    pk && /method call/ && /RemovePackages/ {
      print "Software\t\033[1;33m\tsudo apt-get remove <package>"
      pk=0
    }
    pk && /method call/ && /UpdatePackages/ {
      print "Software\t\033[1;33m\tsudo apt-get upgrade"
      pk=0
    }

    # NetworkManager (system-level state changes)
    /org\.freedesktop\.NetworkManager/ && /StateChanged/ {
      print "Network\t\033[0;34m\t# Network state changed (nmcli general status)"
    }

    # UPower (battery/power events shown by power indicator)
    /org\.freedesktop\.UPower/ && /DeviceChanged/ {
      print "Power\t\033[0;35m\tupower -i /org/freedesktop/UPower/devices/battery_BAT0"
    }
    ' | while IFS=$'\t' read -r src color cmd; do
      _render "\$src" "\$color" "\$cmd"
    done
  ) &
  PIDS+=(\$!)
}

# ── Layer 3: System journal (journalctl) ──────────────────────────────────────
_run_journal_layer() {
  command -v journalctl >/dev/null 2>&1 || return

  journalctl -f -n 0 --output=short 2>/dev/null | while read -r line; do
    case "\$line" in
      # apt/dpkg package operations
      *"apt-get install"*|*"Unpacking "*)
        pkg="\$(echo "\$line" | grep -oP '(?<=Unpacking )[a-zA-Z0-9._+:-]+' | head -1)"
        [ -n "\$pkg" ] && _render "Software" "\${YELLOW}" "sudo apt-get install \$pkg"
        ;;
      *"apt-get remove"*|*"Removing "*)
        pkg="\$(echo "\$line" | grep -oP '(?<=Removing )[a-zA-Z0-9._+:-]+' | head -1)"
        [ -n "\$pkg" ] && _render "Software" "\${YELLOW}" "sudo apt-get remove \$pkg"
        ;;
      *"Upgrade: "*)
        pkg="\$(echo "\$line" | grep -oP '(?<=Upgrade: )[a-zA-Z0-9._+:-]+' | head -1)"
        [ -n "\$pkg" ] && _render "Software" "\${YELLOW}" "sudo apt-get upgrade \$pkg"
        ;;
      # systemd service events
      *"Started "*.service*)
        svc="\$(echo "\$line" | grep -oP '(?<=Started )[^.]+\.service' | head -1)"
        [ -n "\$svc" ] && _render "Service" "\${RED}" "systemctl start \$svc"
        ;;
      *"Stopped "*.service*)
        svc="\$(echo "\$line" | grep -oP '(?<=Stopped )[^.]+\.service' | head -1)"
        [ -n "\$svc" ] && _render "Service" "\${RED}" "systemctl stop \$svc"
        ;;
      *"Reloaded "*.service*)
        svc="\$(echo "\$line" | grep -oP '(?<=Reloaded )[^.]+\.service' | head -1)"
        [ -n "\$svc" ] && _render "Service" "\${RED}" "systemctl reload \$svc"
        ;;
      # ufw/firewall
      *"ufw"*"ALLOW"*|*"ufw"*"DENY"*)
        _render "Firewall" "\${MAGENTA}" "# ufw rule triggered — run: sudo ufw status"
        ;;
      # sshd
      *"Accepted password"*|*"Accepted publickey"*)
        user="\$(echo "\$line" | grep -oP '(?<=for )[a-zA-Z0-9_-]+')"
        [ -n "\$user" ] && _render "SSH" "\${BLUE}" "# Incoming SSH login as \$user"
        ;;
    esac
  done
}

# ── Main: start all layers ─────────────────────────────────────────────────────
_run_fs_layer &
PIDS+=(\$!)

_run_dbus_layer

_run_journal_layer &
PIDS+=(\$!)

# Keep the window alive; all output flows from subshell pipes.
wait
ENGINEEOF

  chmod +x "$engine"
  printf "%s\n" "$engine"
}

# ── User-facing command ───────────────────────────────────────────────────────

showme() {
  local subcmd="${1:-start}"
  shift || true

  case "$subcmd" in
    start|"")
      _showme_check_deps || return 1

      # Determine directories to watch.
      local watch_dirs=""
      if [ "$#" -gt 0 ]; then
        # User supplied specific paths.
        watch_dirs="$*"
      else
        # Default: common desktop directories that actually exist.
        local defaults=("$HOME/Desktop" "$HOME/Documents" "$HOME/Downloads"
                        "$HOME/workspace" "$HOME/dev" "$HOME/projects"
                        "$HOME/Pictures" "$HOME/Music" "$HOME/Videos")
        for d in "${defaults[@]}"; do
          [ -d "$d" ] && watch_dirs="${watch_dirs} $d"
        done
        watch_dirs="${watch_dirs# }"
      fi

      if [ -z "$watch_dirs" ]; then
        err "No watchable directories found. Pass a path: showme ~/mydir"
        return 1
      fi

      local engine
      engine=$(_showme_write_engine "$watch_dirs")

      info "Starting showme..."

      # Check for --inline flag.
      if [ "${SHOWME_INLINE:-0}" = "1" ] || [ "${1:-}" = "--inline" ]; then
        bash "$engine"
      else
        _showme_open_window "$engine"
        ok "showme is running in a new terminal window."
        info "Run 'showme stop' to kill all monitoring processes."
        info "Or just close the showme terminal window."
      fi
      ;;

    stop)
      # Kill any running showme engine processes.
      local killed=0
      while IFS= read -r pid; do
        kill "$pid" 2>/dev/null && (( killed++ )) || true
      done < <(pgrep -f "unishell_showme_engine" 2>/dev/null)

      # Remove any leftover engine scripts from /dev/shm.
      rm -f /dev/shm/unishell_showme_engine_*.sh 2>/dev/null || true

      if [ "$killed" -gt 0 ]; then
        ok "Stopped $killed showme session(s)."
      else
        warn "No showme sessions found running."
      fi
      ;;

    --inline)
      # Run in current terminal (no new window).
      SHOWME_INLINE=1 showme start "$@"
      ;;

    status)
      local count
      count=$(pgrep -c -f "unishell_showme_engine" 2>/dev/null || echo 0)
      if [ "$count" -gt 0 ]; then
        ok "showme is running ($count monitoring process(es) active)."
      else
        warn "showme is not running. Start with: showme"
      fi
      ;;

    help|-h|--help)
      cat <<'EOF'
showme — GUI transparency engine

  showme               Open a new terminal showing commands behind GUI actions
  showme ~/mydir       Watch a specific directory
  showme --inline      Stream to the current terminal instead of a new window
  showme stop          Stop all running showme sessions
  showme status        Check if showme is running

Three monitoring layers:
  ● Filesystem   inotifywait — file create/move/delete/rename/chmod
  ● D-Bus        dbus-monitor — network, USB, Bluetooth, display
  ● Journal      journalctl  — package installs, service changes

Requires: inotify-tools (auto-installs), dbus-tools, systemd
EOF
      ;;

    *)
      err "Unknown subcommand: $subcmd. Run: showme help"
      return 1
      ;;
  esac
}
