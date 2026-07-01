#!/usr/bin/env bash

sysinfo() {
  info "System"
  uname -a

  printf "\n"
  info "CPU"
  if command -v lscpu >/dev/null 2>&1; then
    lscpu | awk -F: '/Model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}'
  elif [ -r /proc/cpuinfo ]; then
    awk -F: '/model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo
  else
    warn "CPU details unavailable"
  fi

  printf "\n"
  info "Memory"
  if command -v free >/dev/null 2>&1; then
    free -h
  else
    warn "free command not available"
  fi

  printf "\n"
  info "Uptime"
  if uptime -p >/dev/null 2>&1; then
    uptime -p
  else
    uptime
  fi
}

ports() {
  if command -v ss >/dev/null 2>&1; then
    ss -tulnp
  elif command -v netstat >/dev/null 2>&1; then
    netstat -tulnp
  else
    err "Neither ss nor netstat is installed."
    return 1
  fi
}

myip() {
  info "Local IP"
  if command -v hostname >/dev/null 2>&1; then
    hostname -I 2>/dev/null | awk '{print $1}'
  elif command -v ip >/dev/null 2>&1; then
    ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}'
  else
    warn "Could not determine local IP"
  fi

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
  if command -v free >/dev/null 2>&1; then
    free -h
  else
    err "free command not available."
    return 1
  fi
}

service-check() {
  local service_name="${1:-}"

  if [ -z "$service_name" ]; then
    err "Usage: service-check service-name"
    return 1
  fi

  if ! command -v systemctl >/dev/null 2>&1; then
    err "systemctl is not available on this system."
    return 1
  fi

  systemctl status "$service_name"
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
# Find and kill whatever process is listening on a given port.
# Wraps ss/lsof/netstat + kill into one safe, confirmed operation.

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

  # Try ss first (most common on modern Linux), then lsof, then netstat.
  if command -v ss >/dev/null 2>&1; then
    pid=$(ss -tlnp 2>/dev/null | grep ":${port} \|:${port}$" | grep -oE 'pid=[0-9]+' | grep -oE '[0-9]+' | head -1)
  fi
  if [ -z "$pid" ] && command -v lsof >/dev/null 2>&1; then
    pid=$(lsof -ti ":$port" 2>/dev/null | head -1)
  fi
  if [ -z "$pid" ] && command -v netstat >/dev/null 2>&1; then
    pid=$(netstat -tlnp 2>/dev/null | awk -v p=":$port" '$4~p{split($NF,a,"/"); print a[1]}' | head -1)
  fi

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
