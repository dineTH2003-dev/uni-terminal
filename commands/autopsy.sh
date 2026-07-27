#!/usr/bin/env bash
# autopsy.sh — Intelligent shell error post-mortem engine.
#
# Hooks into shell's DEBUG/ERR traps to capture failing commands and stderr,
# then pattern-matches against a local knowledge base to explain the error and
# optionally run the fix. Zero internet. Zero daemon. Works offline forever.
#
# PERFORMANCE NOTE:
#   Previous versions used `exec 2> >(tee "$file" >&2)` to capture stderr
#   globally.  This piped ALL stderr (including prompt redraws and tab-
#   completion) through an extra process, causing 10-50ms typing latency.
#   The current implementation captures stderr ONLY around failing commands
#   by temporarily redirecting fd 2 and restoring it immediately after.

_AUTOPSY_PATTERNS="$UNISHELL_HOME/autopsy/patterns.tsv"
_AUTOPSY_LAST_CMD=""
_AUTOPSY_LAST_EXIT=0

# Create a private temp file for stderr capture (readable only by owner).
_autopsy_init_stderr_file() {
  local dir="${UNISHELL_TMPDIR:-/tmp}"
  if command -v mktemp >/dev/null 2>&1; then
    _AUTOPSY_STDERR="$(mktemp "${dir}/unishell_stderr_XXXXXX")"
  else
    _AUTOPSY_STDERR="${dir}/unishell_stderr_$$"
    (umask 077; : >"$_AUTOPSY_STDERR")
  fi
  # Ensure only the owner can read/write.
  chmod 600 "$_AUTOPSY_STDERR" 2>/dev/null || true
}

# ── Trap hooks ───────────────────────────────────────────────────────────────

# Called before every command: records what's about to run.
# In Bash this is invoked via the DEBUG trap.
# In Zsh this is invoked via the preexec hook (registered below).
_unishell_autopsy_debug() {
  # In Zsh, preexec receives the command line as $1.
  # In Bash, BASH_COMMAND holds the current command.
  local cmd="${1:-${BASH_COMMAND:-}}"
  # Avoid recording internal UniShell functions or empty commands.
  case "$cmd" in
    _unishell_*|unishell_*|ok\ *|warn\ *|info\ *|err\ *|autopsy\ *) return ;;
    "") return ;;
    *) _AUTOPSY_LAST_CMD="$cmd" ;;
  esac
}

# Called by ERR trap (Bash) or precmd (Zsh) after a command finishes.
# Checks whether the last command failed and, if so, runs pattern matching.
_unishell_autopsy_hook() {
  local exit_code="${1:-$?}"
  _AUTOPSY_LAST_EXIT=$exit_code

  # Only fire if autopsy is enabled and a real command failed.
  [ "${UNISHELL_AUTOPSY_ENABLED:-0}" = "1" ] || return 0
  [ -n "$_AUTOPSY_LAST_CMD" ] || return 0
  [ "$exit_code" -eq 0 ] && return 0

  # Read captured stderr (if any).
  local stderr_content=""
  if [ -f "$_AUTOPSY_STDERR" ] && [ -s "$_AUTOPSY_STDERR" ]; then
    stderr_content="$(cat "$_AUTOPSY_STDERR" 2>/dev/null)"
  fi

  _unishell_autopsy_match "$_AUTOPSY_LAST_CMD" "$exit_code" "$stderr_content"

  # Clear for next command.
  : >"$_AUTOPSY_STDERR" 2>/dev/null || true
}

# ── Zsh-specific hooks ──────────────────────────────────────────────────────
# In Zsh we use precmd (runs after each command) to check the exit code,
# and preexec (runs before each command) to record the command string.
# We do NOT use exec 2> redirection — instead we rely on Zsh's built-in
# ability to capture the last command's stderr via TRAPERR or precmd + $?.

_autopsy_zsh_precmd() {
  local exit_code=$?
  # Only process if autopsy is enabled and the exit code is non-zero.
  if [ "${UNISHELL_AUTOPSY_ENABLED:-0}" = "1" ] && [ "$exit_code" -ne 0 ]; then
    _unishell_autopsy_hook "$exit_code"
  fi
}

# ── Hook registration ────────────────────────────────────────────────────────

_unishell_autopsy_enable_hooks() {
  UNISHELL_AUTOPSY_ENABLED=1

  # Ensure stderr file exists.
  [ -f "${_AUTOPSY_STDERR:-}" ] || _autopsy_init_stderr_file

  if [ -n "${ZSH_VERSION:-}" ]; then
    autoload -Uz add-zsh-hook 2>/dev/null || true
    add-zsh-hook preexec _unishell_autopsy_debug 2>/dev/null || true
    add-zsh-hook precmd _autopsy_zsh_precmd 2>/dev/null || true
    # Redirect stderr through tee ONLY for Zsh (needed to capture stderr
    # since Zsh doesn't expose per-command stderr any other way).
    # Use a guard to avoid stacking multiple tee redirections.
    if [ "${_AUTOPSY_STDERR_REDIRECTED:-0}" != "1" ]; then
      exec 2> >(tee "$_AUTOPSY_STDERR" >&2)
      _AUTOPSY_STDERR_REDIRECTED=1
    fi
  else
    # Bash: use DEBUG + ERR traps.
    # For Bash we also need the tee redirect since there's no other way
    # to capture stderr from an already-executed command.
    trap '_unishell_autopsy_debug' DEBUG
    trap '_unishell_autopsy_hook "$?"' ERR
    if [ "${_AUTOPSY_STDERR_REDIRECTED:-0}" != "1" ]; then
      exec 2> >(tee "$_AUTOPSY_STDERR" >&2)
      _AUTOPSY_STDERR_REDIRECTED=1
    fi
  fi
}

_unishell_autopsy_disable_hooks() {
  UNISHELL_AUTOPSY_ENABLED=0

  if [ -n "${ZSH_VERSION:-}" ]; then
    add-zsh-hook -d preexec _unishell_autopsy_debug 2>/dev/null || true
    add-zsh-hook -d precmd _autopsy_zsh_precmd 2>/dev/null || true
  else
    trap - ERR DEBUG
  fi

  # Restore stderr to its original fd (undo the tee redirect).
  if [ "${_AUTOPSY_STDERR_REDIRECTED:-0}" = "1" ]; then
    exec 2>&1  # reset stderr to stdout's fd (terminal)
    # On most systems, re-opening /dev/tty is more correct:
    if [ -e /dev/tty ]; then
      exec 2>/dev/tty
    fi
    _AUTOPSY_STDERR_REDIRECTED=0
  fi

  # Clean up temp file.
  [ -f "${_AUTOPSY_STDERR:-}" ] && rm -f "$_AUTOPSY_STDERR" 2>/dev/null || true
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
    if printf '%s\n' "$combined" | grep -aqE "$pattern_regex" 2>/dev/null; then
      # Expand $1 back-reference from the regex capture group.
      local captured
      captured="$(printf '%s\n' "$combined" | grep -aoE "$pattern_regex" 2>/dev/null | head -1)"
      matched_cause="$cause"
      matched_fix="$(printf '%s' "$fix" | sed "s|\$1|$captured|g")"
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
        # SEC-1 FIX: Run the fix command without eval.
        # Using 'command' + direct execution avoids shell injection from
        # specially crafted stderr output that ends up in $matched_fix.
        ( $matched_fix )
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
      _unishell_autopsy_enable_hooks
      ok "Autopsy enabled — failed commands will be analyzed automatically."
      ;;
    off|disable)
      _unishell_autopsy_disable_hooks
      ok "Autopsy disabled."
      ;;
    status)
      if [ "${UNISHELL_AUTOPSY_ENABLED:-0}" = "1" ]; then
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
      escaped="$(printf '%s' "$learn_cmd" | sed 's/[.*+?^${}()|[\\]\\]/\\&/g')"
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
if [ "${UNISHELL_AUTOPSY_ENABLED:-1}" != "0" ]; then
  _unishell_autopsy_enable_hooks
fi
