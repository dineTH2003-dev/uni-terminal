#!/usr/bin/env bash
# context.sh — Cross-session per-project semantic command memory.
#
# Records every command run inside a recognized project directory to a
# per-project journal file. On directory entry, shows a "last active" summary.
# 'context replay' re-runs tagged setup commands interactively.
#
# Storage: ~/.unishell/context/<project-name-hash>.log (plain append-only text)
# Zero daemons. Append-only I/O. One string comparison per prompt tick.

_CONTEXT_DIR="$UNISHELL_HOME/context"
_CONTEXT_REDACT_PATTERNS='(password|passwd|secret|token|key|auth|credential)=[^ ]+'

# ── Internal helpers ─────────────────────────────────────────────────────────

_context_project_id() {
  # Use basename + parent dir to avoid collisions (e.g. two "src" dirs).
  local proj="${PWD##*/}"
  local parent="${PWD%/*}"; parent="${parent##*/}"
  printf "%s_%s" "$parent" "$proj" | tr -cs 'a-zA-Z0-9_-' '_'
}

_context_log_path() {
  printf "%s/%s.log\n" "$_CONTEXT_DIR" "$(_context_project_id)"
}

_context_setup_path() {
  printf "%s/%s.setup\n" "$_CONTEXT_DIR" "$(_context_project_id)"
}

# Redact sensitive patterns before writing to log.
_context_redact() {
  sed -E "s|${_CONTEXT_REDACT_PATTERNS}|\\1=***REDACTED***|gI" 2>/dev/null || cat
}

# ── Passive PROMPT_COMMAND hook (replaces no-op stub from loader) ────────────

_unishell_context_hook() {
  # Only operate inside a workspace or recognized project dir.
  case "$PWD" in
    "$WORKSPACE_DIR"/*|"$HOME/projects"/*|"$HOME/dev"/*) ;;
    *) return ;;
  esac

  local log; log="$(_context_log_path)"
  mkdir -p "$_CONTEXT_DIR"

  # Show "last active" summary only when first entering this dir this session.
  local session_marker="/dev/shm/unishell_ctx_$$_$(_context_project_id)"
  if [ ! -f "$session_marker" ]; then
    touch "$session_marker"
    if [ -f "$log" ]; then
      local last_date last_cmds
      last_date=$(tail -1 "$log" 2>/dev/null | awk -F'\t' '{print $1}')
      last_cmds=$(grep -v '^#' "$log" 2>/dev/null | tail -3 | awk -F'\t' '{print $3}' | tr '\n' ',' | sed 's/,$//')
      if [ -n "$last_date" ]; then
        printf "%b\n" "${CYAN}📂 ${BOLD}$(basename "$PWD")${NC}${CYAN} — last active: ${last_date%%T*}${NC}"
        [ -n "$last_cmds" ] && printf "%b\n" "   ${BLUE}Last ran:${NC} $last_cmds"
        local setup; setup="$(_context_setup_path)"
        if [ -f "$setup" ]; then
          printf "%b\n" "   ${GREEN}⚡ Run 'context replay' to re-run your setup commands${NC}"
        fi
      fi
    fi
  fi

  # Hook history: record commands as they're run via PROMPT_COMMAND.
  # We read the last history entry each prompt tick.
  local last_cmd
  last_cmd=$(HISTTIMEFORMAT='' history 1 2>/dev/null | sed 's/^ *[0-9]* *//')

  # Skip blanks, UniShell internals, and duplicate of what was just shown.
  case "$last_cmd" in
    ""|_unishell_*|context*|unishell*) return ;;
  esac

  local timestamp; timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  local redacted_cmd; redacted_cmd=$(printf "%s" "$last_cmd" | _context_redact)
  printf "%s\t%s\t%s\n" "$timestamp" "$PWD" "$redacted_cmd" >> "$log"
}

# ── User-facing command ──────────────────────────────────────────────────────

context() {
  local subcmd="${1:-log}"
  shift || true

  local log; log="$(_context_log_path)"
  local setup; setup="$(_context_setup_path)"

  case "$subcmd" in
    log|history)
      if [ ! -f "$log" ]; then
        warn "No history for project '$(basename "$PWD")' yet."
        info "Commands you run here will be logged automatically."
        return 0
      fi
      local n="${1:-20}"
      info "Last $n commands in '$(basename "$PWD")':"
      printf "\n"
      tail -n "$n" "$log" | awk -F'\t' '{printf "  \033[0;36m%s\033[0m  %s\n", substr($1,1,16), $3}'
      ;;
    mark-setup|setup)
      # Tag the N most recent commands as "setup commands" for this project.
      if [ ! -f "$log" ]; then
        warn "No command history yet — run some setup commands first."
        return 1
      fi
      local n="${1:-5}"
      info "Marking last $n commands as setup commands for '$(basename "$PWD")':"
      tail -n "$n" "$log" | awk -F'\t' '{print $3}' | tee "$setup" | sed 's/^/  /'
      ok "Saved. Run 'context replay' to re-run these."
      ;;
    replay)
      if [ ! -f "$setup" ]; then
        warn "No setup commands marked for '$(basename "$PWD")'."
        info "Use 'context mark-setup' after your first setup."
        return 1
      fi
      info "Replaying setup commands for '$(basename "$PWD")':"
      printf "\n"
      while IFS= read -r cmd || [ -n "$cmd" ]; do
        [ -z "$cmd" ] && continue
        printf "%b" "  ${BOLD}→ ${cmd}${NC}  run? (y/n/q): "
        local ans; read -r ans
        case "$ans" in
          q|Q) warn "Replay stopped."; return 0 ;;
          y|Y|yes|YES) eval "$cmd" ;;
          *) info "Skipped." ;;
        esac
      done <"$setup"
      ok "Replay complete."
      ;;
    search)
      local term="${1:-}"
      [ -z "$term" ] && err "Usage: context search <term>" && return 1
      [ ! -f "$log" ] && warn "No history yet." && return 0
      info "Commands matching '$term' in '$(basename "$PWD")':"
      grep -i "$term" "$log" | awk -F'\t' '{printf "  \033[0;36m%s\033[0m  %s\n", substr($1,1,16), $3}'
      ;;
    clear)
      if [ -f "$log" ]; then
        printf "Delete command history for '$(basename "$PWD")'? (y/N): "
        local confirm; read -r confirm
        case "$confirm" in
          y|Y|yes|YES) rm -f "$log" "$setup"; ok "History cleared." ;;
          *) warn "Cancelled." ;;
        esac
      else
        warn "No history file to clear."
      fi
      ;;
    projects|list)
      if [ -z "$(ls -A "$_CONTEXT_DIR" 2>/dev/null)" ]; then
        warn "No project history saved yet."
      else
        info "Projects with saved context:"
        ls -1 "$_CONTEXT_DIR"/*.log 2>/dev/null | while read -r f; do
          local name; name=$(basename "$f" .log | tr '_' '/')
          local count; count=$(wc -l <"$f" 2>/dev/null || echo 0)
          local last; last=$(tail -1 "$f" 2>/dev/null | cut -f1 | cut -c1-16)
          printf "  %-30s  %4d cmds  last: %s\n" "$name" "$count" "$last"
        done
      fi
      ;;
    help|-h|--help)
      cat <<'EOF'
context — per-project command memory and session replay

  context log [N]          Show last N commands in this project (default: 20)
  context mark-setup [N]   Tag last N commands as setup commands (default: 5)
  context replay           Re-run your saved setup commands interactively
  context search TERM      Search command history for a term
  context clear            Delete history for the current project
  context projects         List all projects with saved history

Commands are logged automatically when you work inside ~/workspace or ~/dev.
Secrets matching common patterns (password=, token=, etc.) are redacted.
EOF
      ;;
    *)
      err "Unknown subcommand: $subcmd. Run: context help"
      return 1
      ;;
  esac
}
