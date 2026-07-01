#!/usr/bin/env bash
# broadcast.sh — Read-only terminal streaming to a browser over LAN.
#
# Uses 'script' (records terminal I/O to a FIFO in RAM), a pure-Bash HTTP
# server over 'nc' (netcat), and an awk ANSI-to-HTML converter to serve
# a live terminal stream to any browser tab on the LAN.
#
# Zero accounts. Zero cloud. Zero compiled binaries beyond what's on Linux.
# Read-only: the HTTP server only reads the FIFO, it never writes to the TTY.

_BROADCAST_PORT="${UNISHELL_BROADCAST_PORT:-7681}"
_BROADCAST_FIFO="/dev/shm/unishell_cast_$$"
_BROADCAST_PID_FILE="/dev/shm/unishell_broadcast_pid_$$"
_BROADCAST_SCRIPT_PID=""

# ── Dependency check ─────────────────────────────────────────────────────────

_broadcast_check_deps() {
  local missing=()
  command -v script >/dev/null 2>&1 || missing+=("script (util-linux)")
  command -v nc     >/dev/null 2>&1 || missing+=("nc (netcat)")
  command -v awk    >/dev/null 2>&1 || missing+=("awk")
  if [ "${#missing[@]}" -gt 0 ]; then
    err "broadcast requires: ${missing[*]}"
    info "Install with: sudo apt install util-linux netcat-openbsd"
    return 1
  fi
  return 0
}

# ── Local IP detection ───────────────────────────────────────────────────────

_broadcast_local_ip() {
  if command -v ip >/dev/null 2>&1; then
    ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1); exit}'
  elif command -v hostname >/dev/null 2>&1; then
    hostname -I 2>/dev/null | awk '{print $1}'
  else
    echo "127.0.0.1"
  fi
}

# ── HTML page served to the browser ─────────────────────────────────────────

_broadcast_html() {
  cat <<'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>UniShell Broadcast</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background: #0d1117;
    color: #c9d1d9;
    font-family: 'Cascadia Code', 'Fira Code', 'Consolas', monospace;
    font-size: 14px;
    line-height: 1.5;
    padding: 20px;
  }
  #header {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 16px;
    padding-bottom: 12px;
    border-bottom: 1px solid #30363d;
  }
  .dot { width: 12px; height: 12px; border-radius: 50%; }
  .dot-red { background: #ff5f57; }
  .dot-yellow { background: #febc2e; }
  .dot-green { background: #28c840; }
  #status {
    margin-left: auto;
    font-size: 12px;
    color: #8b949e;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .live-dot {
    width: 8px; height: 8px;
    background: #2dba4e;
    border-radius: 50%;
    animation: pulse 1.5s infinite;
  }
  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.3; }
  }
  #terminal {
    white-space: pre-wrap;
    word-break: break-all;
    min-height: 80vh;
  }
  /* ANSI colors */
  .f0{color:#000}.f1{color:#cd0000}.f2{color:#00cd00}.f3{color:#cdcd00}
  .f4{color:#0000ee}.f5{color:#cd00cd}.f6{color:#00cdcd}.f7{color:#e5e5e5}
  .f9{color:#c9d1d9}.b1{color:#f44336}.b2{color:#4caf50}.b3{color:#ffeb3b}
  .b4{color:#2196f3}.b5{color:#e040fb}.b6{color:#00bcd4}.b9{color:#e0e0e0}
  .bold{font-weight:bold}.dim{opacity:0.6}.underline{text-decoration:underline}
</style>
</head>
<body>
<div id="header">
  <div class="dot dot-red"></div>
  <div class="dot dot-yellow"></div>
  <div class="dot dot-green"></div>
  <span style="color:#8b949e;font-size:13px;">UniShell Broadcast — Read Only</span>
  <div id="status"><div class="live-dot"></div> LIVE</div>
</div>
<div id="terminal"></div>
<script>
const term = document.getElementById('terminal');
const src  = new EventSource('/stream');
let buf = '';
src.onmessage = (e) => {
  buf += e.data + '\n';
  // Keep last 2000 lines to avoid memory growth.
  const lines = buf.split('\n');
  if (lines.length > 2000) buf = lines.slice(-2000).join('\n');
  term.innerHTML = buf;
  window.scrollTo(0, document.body.scrollHeight);
};
src.onerror = () => {
  document.getElementById('status').innerHTML = '<span style="color:#f44336">● DISCONNECTED</span>';
};
</script>
</body>
</html>
HTMLEOF
}

# ── Pure-awk ANSI to HTML span converter ────────────────────────────────────

_broadcast_ansi_to_html() {
  # Streams from stdin, converts ANSI escape sequences to HTML spans.
  # Prints each output line as an SSE data: message.
  awk '
  BEGIN {
    bold=0; dim=0; uline=0; fg="f9"
    ansi_map[30]="f0";ansi_map[31]="f1";ansi_map[32]="f2";ansi_map[33]="f3"
    ansi_map[34]="f4";ansi_map[35]="f5";ansi_map[36]="f6";ansi_map[37]="f7"
    ansi_map[39]="f9";ansi_map[90]="b1";ansi_map[91]="b1";ansi_map[92]="b2"
    ansi_map[93]="b3";ansi_map[94]="b4";ansi_map[95]="b5";ansi_map[96]="b6"
    ansi_map[97]="b9"
  }
  {
    line = $0
    out = ""
    while (match(line, /\033\[[0-9;]*m/)) {
      pre = substr(line, 1, RSTART-1)
      esc = substr(line, RSTART, RLENGTH)
      line = substr(line, RSTART+RLENGTH)
      out = out html_escape(pre)
      # Parse SGR codes
      codes = substr(esc, 3, length(esc)-3)
      n = split(codes, c, ";")
      for (i=1; i<=n; i++) {
        v = c[i]+0
        if (v==0)  { bold=0; dim=0; uline=0; fg="f9" }
        else if (v==1) bold=1
        else if (v==2) dim=1
        else if (v==4) uline=1
        else if (v in ansi_map) fg=ansi_map[v]
      }
      cls = fg
      if (bold) cls = cls " bold"
      if (dim)  cls = cls " dim"
      if (uline) cls = cls " underline"
      out = out "<span class=\"" cls "\">"
    }
    out = out html_escape(line) "</span>"
    print "data: " out "\n"
    fflush()
  }
  function html_escape(s,    r) {
    r = s
    gsub(/&/, "\\&amp;", r); gsub(/</, "\\&lt;", r); gsub(/>/, "\\&gt;", r)
    return r
  }
  '
}

# ── HTTP server (pure Bash + nc) ─────────────────────────────────────────────

_broadcast_serve_once() {
  local fifo="$1"
  # Read the HTTP request line.
  local request
  read -r request
  local path; path=$(echo "$request" | awk '{print $2}')

  case "$path" in
    /stream)
      printf "HTTP/1.1 200 OK\r\n"
      printf "Content-Type: text/event-stream\r\n"
      printf "Cache-Control: no-cache\r\n"
      printf "Access-Control-Allow-Origin: *\r\n"
      printf "Connection: keep-alive\r\n"
      printf "\r\n"
      # Stream the FIFO content, converting ANSI to HTML SSE events.
      tail -f "$fifo" | _broadcast_ansi_to_html
      ;;
    *)
      # Serve the HTML page for any other path.
      local body; body=$(_broadcast_html)
      printf "HTTP/1.1 200 OK\r\n"
      printf "Content-Type: text/html; charset=UTF-8\r\n"
      printf "Content-Length: %d\r\n" "${#body}"
      printf "Connection: close\r\n"
      printf "\r\n"
      printf "%s" "$body"
      ;;
  esac
}

# Run a persistent HTTP server that handles one connection at a time.
_unishell_broadcast_server() {
  local fifo="$1"
  while true; do
    _broadcast_serve_once "$fifo" | nc -l -p "$_BROADCAST_PORT" -q 1 2>/dev/null || \
    _broadcast_serve_once "$fifo" | nc -l    "$_BROADCAST_PORT"       2>/dev/null || break
  done
}

# ── User-facing command ──────────────────────────────────────────────────────

broadcast() {
  local subcmd="${1:-start}"
  shift || true

  case "$subcmd" in
    start)
      _broadcast_check_deps || return 1

      if [ -f "$_BROADCAST_PID_FILE" ]; then
        warn "Broadcast is already running. Run: broadcast stop"
        return 1
      fi

      local local_ip; local_ip=$(_broadcast_local_ip)

      # Create the RAM-backed FIFO.
      rm -f "$_BROADCAST_FIFO"
      mkfifo "$_BROADCAST_FIFO" || { err "Failed to create FIFO in /dev/shm"; return 1; }

      # Start the HTTP server in the background.
      _unishell_broadcast_server "$_BROADCAST_FIFO" &
      local server_pid=$!
      printf "%d" "$server_pid" >"$_BROADCAST_PID_FILE"

      printf "\n"
      printf "%b\n" "  ${GREEN}📡 Broadcasting terminal — read-only${NC}"
      printf "%b\n" "  ${BOLD}LAN URL: http://${local_ip}:${_BROADCAST_PORT}${NC}"
      printf "%b\n" "  Share this with your professor or teammate."
      printf "%b\n" "  ${YELLOW}Press Ctrl+C or run 'broadcast stop' to end.${NC}"
      printf "\n"

      # Use 'script' to capture terminal output to the FIFO.
      # This is what feeds the browser stream.
      trap '_broadcast_cleanup' INT TERM EXIT

      script -q -f "$_BROADCAST_FIFO" 2>/dev/null || \
      script    -f "$_BROADCAST_FIFO" 2>/dev/null

      _broadcast_cleanup
      ;;
    stop)
      _broadcast_cleanup
      ok "Broadcast stopped."
      ;;
    status)
      if [ -f "$_BROADCAST_PID_FILE" ]; then
        local pid; pid=$(cat "$_BROADCAST_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
          ok "Broadcast is running (PID $pid)"
          info "URL: http://$(_broadcast_local_ip):${_BROADCAST_PORT}"
        else
          warn "Broadcast PID file exists but process is dead. Run: broadcast stop"
        fi
      else
        warn "Broadcast is not running."
      fi
      ;;
    help|-h|--help)
      cat <<'EOF'
broadcast — read-only terminal sharing over LAN

  broadcast start     Start streaming your terminal to a browser
  broadcast stop      Stop the broadcast
  broadcast status    Check if broadcast is running

How it works:
  1. 'script' records your terminal output to a RAM-backed FIFO
  2. A pure-Bash HTTP server streams it as Server-Sent Events
  3. An awk ANSI→HTML converter renders colors in the browser
  4. Your teammate opens the URL in any browser — read-only, real-time

Requirements: script, nc (netcat), awk — all standard Linux tools.
Set UNISHELL_BROADCAST_PORT=<n> to change the default port (7681).
EOF
      ;;
    *)
      err "Unknown subcommand: $subcmd. Run: broadcast help"
      return 1
      ;;
  esac
}

_broadcast_cleanup() {
  if [ -f "$_BROADCAST_PID_FILE" ]; then
    local pid; pid=$(cat "$_BROADCAST_PID_FILE")
    kill "$pid" 2>/dev/null || true
    rm -f "$_BROADCAST_PID_FILE"
  fi
  rm -f "$_BROADCAST_FIFO"
  trap - INT TERM EXIT
}
