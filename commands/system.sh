#!/usr/bin/env bash

sysinfo() {
  info "System"
  uname -a

  printf "\n"
  info "CPU"
  case "${UNISHELL_PLATFORM:-linux}" in
    macos)
      sysctl -n machdep.cpu.brand_string 2>/dev/null || warn "CPU info unavailable"
      ;;
    gitbash)
      # Parse systeminfo on Windows (Git Bash).
      if command -v systeminfo >/dev/null 2>&1; then
        systeminfo 2>/dev/null | awk -F: '/Processor/ {gsub(/^[ \t]+/, "", $2); print $2; exit}'
      else
        warn "CPU details unavailable on Git Bash"
      fi
      ;;
    *)
      if command -v lscpu >/dev/null 2>&1; then
        lscpu | awk -F: '/Model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}'
      elif [ -r /proc/cpuinfo ]; then
        awk -F: '/model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo
      else
        warn "CPU details unavailable"
      fi
      ;;
  esac

  printf "\n"
  info "Memory"
  case "${UNISHELL_PLATFORM:-linux}" in
    macos)
      local mem_bytes; mem_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
      local mem_gb=$(( mem_bytes / 1073741824 ))
      printf "Total: %d GB\n" "$mem_gb"
      # Show memory pressure via vm_stat.
      vm_stat 2>/dev/null | awk '/Pages free/ {free=$NF} /Pages active/ {active=$NF} END {
        gsub(/\./,"",free); gsub(/\./,"",active);
        printf "Free:  %.1f GB  Active: %.1f GB\n", free*4096/1073741824, active*4096/1073741824
      }'
      ;;
    gitbash)
      if command -v systeminfo >/dev/null 2>&1; then
        systeminfo 2>/dev/null | grep -i "Total Physical Memory\|Available Physical Memory"
      else
        warn "Memory info unavailable on Git Bash"
      fi
      ;;
    *)
      if command -v free >/dev/null 2>&1; then
        free -h
      else
        warn "free command not available"
      fi
      ;;
  esac

  printf "\n"
  info "Uptime"
  if uptime -p >/dev/null 2>&1; then
    uptime -p
  else
    uptime
  fi
}

ports() {
  case "${UNISHELL_PLATFORM:-linux}" in
    macos)
      if command -v lsof >/dev/null 2>&1; then
        lsof -iTCP -sTCP:LISTEN -n -P
      else
        err "lsof not available."
        return 1
      fi
      ;;
    gitbash)
      if command -v netstat >/dev/null 2>&1; then
        netstat -an | grep LISTEN
      else
        err "ports is not available on Git Bash."
        info "Use PowerShell: Get-NetTCPConnection -State Listen"
        return 1
      fi
      ;;
    *)
      if command -v ss >/dev/null 2>&1; then
        ss -tulnp
      elif command -v netstat >/dev/null 2>&1; then
        netstat -tulnp
      else
        err "Neither ss nor netstat is installed."
        return 1
      fi
      ;;
  esac
}

myip() {
  info "Local IP"
  case "${UNISHELL_PLATFORM:-linux}" in
    macos)
      ifconfig 2>/dev/null | awk '/inet / && !/127.0.0.1/ {print $2; exit}'
      ;;
    gitbash)
      ipconfig 2>/dev/null | awk '/IPv4/ {print $NF; exit}'
      ;;
    *)
      if command -v hostname >/dev/null 2>&1; then
        hostname -I 2>/dev/null | awk '{print $1}'
      elif command -v ip >/dev/null 2>&1; then
        ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}'
      else
        warn "Could not determine local IP"
      fi
      ;;
  esac

  info "Public IP"
  if command -v curl >/dev/null 2>&1; then
    if ! curl -fsS --max-time 3 https://ifconfig.me 2>/dev/null; then
      warn "Could not reach public IP endpoint"
    else
      printf "\n"
    fi
  else
    warn "curl is not installed; public IP unavailable"
  fi
}

diskcheck() {
  df -h
}

memcheck() {
  case "${UNISHELL_PLATFORM:-linux}" in
    macos)
      local mem_bytes; mem_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
      local mem_gb=$(( mem_bytes / 1073741824 ))
      printf "Total: %d GB\n" "$mem_gb"
      vm_stat 2>/dev/null
      ;;
    gitbash)
      if command -v systeminfo >/dev/null 2>&1; then
        systeminfo 2>/dev/null | grep -i "Physical Memory"
      else
        err "Memory info unavailable on Git Bash."
        return 1
      fi
      ;;
    *)
      if command -v free >/dev/null 2>&1; then
        free -h
      else
        err "free command not available."
        return 1
      fi
      ;;
  esac
}

service-check() {
  local service_name="${1:-}"

  if [ -z "$service_name" ]; then
    err "Usage: service-check service-name"
    return 1
  fi

  case "${UNISHELL_PLATFORM:-linux}" in
    macos)
      if command -v launchctl >/dev/null 2>&1; then
        launchctl list 2>/dev/null | grep -i "$service_name"
      else
        err "launchctl not available."
        return 1
      fi
      ;;
    gitbash)
      err "service-check is not available on Git Bash."
      info "Use PowerShell: Get-Service $service_name"
      return 1
      ;;
    *)
      if ! command -v systemctl >/dev/null 2>&1; then
        err "systemctl is not available on this system."
        return 1
      fi
      systemctl status "$service_name"
      ;;
  esac
}

docker-clean() {
  if ! command -v docker >/dev/null 2>&1; then
    err "Docker is not installed."
    return 1
  fi

  local confirm="${1:-}"
  if [ "$confirm" != "--yes" ]; then
    warn "This removes stopped containers and dangling images."
    printf "Continue? (y/N): "
    read -r confirm
  fi

  case "$confirm" in
    y|Y|yes|YES|--yes)
      docker container prune -f
      docker image prune -f
      ok "Docker cleanup complete"
      ;;
    *)
      warn "Cancelled."
      ;;
  esac
}

# ── killport ──────────────────────────────────────────────────────────────────

killport() {
  local port="${1:-}"

  if [ -z "$port" ]; then
    err "Usage: killport PORT"
    return 1
  fi

  if ! printf '%s' "$port" | grep -qE '^[0-9]+$' || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    err "Invalid port: $port (must be 1–65535)"
    return 1
  fi

  local pid="" process_name=""

  case "${UNISHELL_PLATFORM:-linux}" in
    macos)
      pid=$(lsof -ti ":$port" 2>/dev/null | head -1)
      ;;
    gitbash)
      err "killport is not available on Git Bash."
      info "Use PowerShell: Stop-Process -Id (Get-NetTCPConnection -LocalPort $port).OwningProcess"
      return 1
      ;;
    *)
      # Try ss first, then lsof, then netstat.
      if command -v ss >/dev/null 2>&1; then
        pid=$(ss -tlnp 2>/dev/null | grep ":${port} \|:${port}$" | grep -oE 'pid=[0-9]+' | grep -oE '[0-9]+' | head -1)
      fi
      if [ -z "$pid" ] && command -v lsof >/dev/null 2>&1; then
        pid=$(lsof -ti ":$port" 2>/dev/null | head -1)
      fi
      if [ -z "$pid" ] && command -v netstat >/dev/null 2>&1; then
        pid=$(netstat -tlnp 2>/dev/null | awk -v p=":$port" '$4~p{split($NF,a,"/"); print a[1]}' | head -1)
      fi
      ;;
  esac

  if [ -z "$pid" ]; then
    warn "No process found listening on port $port."
    return 0
  fi

  process_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
  printf "%b\n" "${YELLOW}[WARN]${NC} Found: ${BOLD}${process_name}${NC} (PID $pid) on port $port"
  printf "%b" "Kill it? (y/N): "
  local confirm; read -r confirm
  case "$confirm" in
    y|Y|yes|YES)
      if kill "$pid" 2>/dev/null; then
        ok "Killed $process_name (PID $pid). Port $port is now free."
      elif command -v sudo >/dev/null 2>&1 && sudo kill "$pid" 2>/dev/null; then
        ok "Killed $process_name (PID $pid) with sudo. Port $port is now free."
      else
        err "Failed to kill PID $pid — permission denied."
        return 1
      fi
      ;;
    *)
      warn "Cancelled."
      ;;
  esac
}
