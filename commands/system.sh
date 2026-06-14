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
