#!/usr/bin/env bash
# autopsy.sh — Intelligent shell error post-mortem engine.
#
# Hooks into shell's DEBUG/ERR traps to capture failing commands and stderr,
# then pattern-matches against a local knowledge base to explain the error and
# optionally run the fix. Zero internet. Zero daemon. Works offline forever.

_AUTOPSY_PATTERNS="$UNISHELL_HOME/autopsy/patterns.tsv"
_AUTOPSY_STDERR="/dev/shm/unishell_stderr_$$"
_AUTOPSY_LAST_CMD=""
_AUTOPSY_LAST_EXIT=0

# ── Trap hooks ───────────────────────────────────────────────────────────────

# Called by DEBUG trap before every command: records what's about to run.
_unishell_autopsy_debug() {
  # Avoid recording internal UniShell functions or empty commands.
  local cmd="$BASH_COMMAND"
  case "$cmd" in
    _unishell_*|unishell_*|ok\ *|warn\ *|info\ *|err\ *) return ;;
    *) _AUTOPSY_LAST_CMD="$cmd" ;;
  esac
}

# Called by ERR trap after any command exits non-zero.
_unishell_autopsy_hook() {
  local exit_code=$?
  _AUTOPSY_LAST_EXIT=$exit_code

  # Only fire if autopsy is enabled and a real command failed.
  [ "${UNISHELL_AUTOPSY_ENABLED:-1}" = "1" ] || return
  [ -n "$_AUTOPSY_LAST_CMD" ] || return
  [ "$exit_code" -eq 0 ] && return

  local stderr_content=""
  [ -f "$_AUTOPSY_STDERR" ] && stderr_content="$(cat "$_AUTOPSY_STDERR" 2>/dev/null)"

  _unishell_autopsy_match "$_AUTOPSY_LAST_CMD" "$exit_code" "$stderr_content"
  : >"$_AUTOPSY_STDERR" 2>/dev/null || true  # clear for next command
}

# ── Pattern matching engine ──────────────────────────────────────────────────

_unishell_autopsy_match() {
  local cmd="$1"
  local exit_code="$2"
  local stderr="$3"
  local combined="${stderr}${cmd}"

  [ -f "$_AUTOPSY_PATTERNS" ] || return

  local matched_cause=""
  local matched_fix=""
  local matched_learn=""

  while IFS=$'\t' read -r pattern_exit pattern_regex cause fix learn || [ -n "$pattern_exit" ]; do
    # Skip comments and blank lines.
    case "$pattern_exit" in "#"*|"") continue ;; esac
    # Check exit code match (wildcard '*' matches any).
    if [ "$pattern_exit" != "*" ] && [ "$pattern_exit" != "$exit_code" ]; then
      continue
    fi
    # Check regex match against combined stderr+command string.
    if echo "$combined" | grep -qE "$pattern_regex" 2>/dev/null; then
      # Expand $1 back-reference from the regex capture group.
      local captured
      captured="$(echo "$combined" | grep -oE "$pattern_regex" | head -1)"
      matched_cause="$cause"
      matched_fix="$(echo "$fix" | sed "s|\$1|$captured|g")"
      matched_learn="$learn"
      break
    fi
  done <"$_AUTOPSY_PATTERNS"

  [ -z "$matched_cause" ] && return  # No pattern matched — stay silent.

  # ── Display the autopsy report ───────────────────────────────────────────
  printf "\n"
  printf "%b\n" "  ${RED}✖${NC}  ${BOLD}${_AUTOPSY_LAST_CMD}${NC}  exited ${YELLOW}${exit_code}${NC}"
  printf "\n"
  printf "%b\n" "  ${BLUE}🔎 Cause:${NC}   $matched_cause"
  if [ -n "$matched_fix" ] && [ "$matched_fix" != "-" ]; then
    printf "%b\n" "  ${GREEN}🔧 Fix:${NC}     ${BOLD}${matched_fix}${NC}"
    if [ -n "$matched_learn" ]; then
      printf "%b\n" "  ${CYAN}📚 Learn:${NC}   $matched_learn"
    fi
    printf "\n"
    printf "%b" "  Run the fix? (y/N): "
    local confirm
    read -r confirm
    case "$confirm" in
      y|Y|yes|YES)
        printf "%b\n" "  ${GREEN}→${NC} ${matched_fix}"
        eval "$matched_fix"
        ;;
    esac
  else
    [ -n "$matched_learn" ] && printf "%b\n" "  ${CYAN}📚 Learn:${NC}   $matched_learn"
  fi
  printf "\n"
}

# ── User-facing command ──────────────────────────────────────────────────────

autopsy() {
  local subcmd="${1:-status}"
  shift || true

  case "$subcmd" in
    on|enable)
      UNISHELL_AUTOPSY_ENABLED=1
      # Activate the ERR trap for this session.
      trap '_unishell_autopsy_hook' ERR
      trap '_unishell_autopsy_debug' DEBUG
      # Redirect all stderr to tee into our capture file.
      exec 2> >(tee "$_AUTOPSY_STDERR" >&2)
      ok "Autopsy enabled — failed commands will be analyzed automatically."
      ;;
    off|disable)
      UNISHELL_AUTOPSY_ENABLED=0
      trap - ERR DEBUG
      ok "Autopsy disabled."
      ;;
    status)
      if [ "${UNISHELL_AUTOPSY_ENABLED:-1}" = "1" ]; then
        ok "Autopsy is enabled."
      else
        warn "Autopsy is disabled. Run: autopsy on"
      fi
      info "Pattern database: $_AUTOPSY_PATTERNS"
      local count=0
      [ -f "$_AUTOPSY_PATTERNS" ] && count=$(grep -cv '^#\|^$' "$_AUTOPSY_PATTERNS" 2>/dev/null || echo 0)
      info "Patterns loaded: $count"
      ;;
    learn)
      # autopsy learn "command-that-failed" "what fixed it" "explanation"
      local learn_cmd="${1:-}"
      local learn_fix="${2:-}"
      local learn_why="${3:-}"
      if [ -z "$learn_cmd" ] || [ -z "$learn_fix" ]; then
        err "Usage: autopsy learn \"failed-command\" \"fix-command\" [\"explanation\"]"
        return 1
      fi
      local user_patterns="$UNISHELL_HOME/autopsy/user-patterns.tsv"
      mkdir -p "$(dirname "$user_patterns")"
      # Simple literal pattern from the command fragment.
      local escaped
      escaped="$(printf '%s' "$learn_cmd" | sed 's/[.*+?^${}()|[\]\\]/\\&/g')"
      printf "%s\t%s\t%s\t%s\t%s\n" \
        "*" "$escaped" "User-defined pattern for: $learn_cmd" "$learn_fix" "$learn_why" \
        >> "$user_patterns"
      ok "Pattern saved to $user_patterns"
      ;;
    help|-h|--help)
      cat <<'EOF'
autopsy — intelligent shell error post-mortem

  autopsy on          Enable autopsy for this session
  autopsy off         Disable autopsy for this session
  autopsy status      Show current status and pattern count
  autopsy learn CMD FIX [EXPLAIN]
                      Teach autopsy a new fix pattern

Autopsy activates automatically after UniShell loads.
Set UNISHELL_AUTOPSY_ENABLED=0 before loading UniShell to start disabled.
EOF
      ;;
    *)
      err "Unknown subcommand: $subcmd. Run: autopsy help"
      return 1
      ;;
  esac
}

# Auto-activate autopsy when this module first loads (unless explicitly disabled).
if [ "${UNISHELL_AUTOPSY_ENABLED:-1}" = "1" ]; then
  trap '_unishell_autopsy_hook' ERR
  trap '_unishell_autopsy_debug' DEBUG
  exec 2> >(tee "$_AUTOPSY_STDERR" >&2)
fi
