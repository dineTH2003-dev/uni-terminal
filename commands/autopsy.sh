#!/usr/bin/env bash
# autopsy.sh — Intelligent shell error post-mortem engine.
#
# Hooks into shell traps to capture failing commands and their stderr,
# then pattern-matches against a local knowledge base to explain the error
# and optionally run the fix. Zero internet. Zero daemon. Works offline.
#
# ── Zsh + Oh-My-Zsh / Powerlevel10k Architecture Note ────────────────────────
# In Zsh with p9k/omz, $? is reset to 0 by p9k's git-polling hooks before
# our precmd hook runs.  The ONLY reliable solution is Zsh's TRAPERR function
# (alias: TRAPZERR), which fires IMMEDIATELY after any interactive command
# exits non-zero — before any precmd hook.  We save the real exit code there
# and read it back from precmd, completely bypassing the p9k ordering issue.
#
# Bash uses the ERR + DEBUG trap pair — still the most reliable approach there.

_AUTOPSY_PATTERNS="$UNISHELL_HOME/autopsy/patterns.tsv"
: "${_AUTOPSY_LAST_CMD:=}"
: "${_AUTOPSY_LAST_EXIT:=0}"
: "${_AUTOPSY_SAVED_EXIT:=0}"        # Written by TRAPERR; read by precmd hook.
: "${_AUTOPSY_STDERR_REDIRECTED:=0}"

# ── Temp-file initialisation ─────────────────────────────────────────────────

_autopsy_init_stderr_file() {
  local dir="${UNISHELL_TMPDIR:-/tmp}"
  if command -v mktemp >/dev/null 2>&1; then
    _AUTOPSY_STDERR="$(mktemp "${dir}/unishell_stderr_XXXXXX")"
  else
    _AUTOPSY_STDERR="${dir}/unishell_stderr_$$"
    ( umask 077; : >"$_AUTOPSY_STDERR" )
  fi
  chmod 600 "$_AUTOPSY_STDERR" 2>/dev/null || true
}

# ── Shared hooks ─────────────────────────────────────────────────────────────

# Fires before every interactive command (preexec in Zsh, DEBUG trap in Bash).
# Records the command string so the report can show what failed.
_unishell_autopsy_debug() {
  local cmd="${1:-${BASH_COMMAND:-}}"
  case "$cmd" in
    _unishell_*|unishell_*|autopsy*|ok\ *|warn\ *|info\ *|err\ *|"") return ;;
  esac
  _AUTOPSY_LAST_CMD="$cmd"
}

# Runs the pattern-match + display logic.
_unishell_autopsy_hook() {
  local exit_code="${1:-1}"
  _AUTOPSY_LAST_EXIT=$exit_code

  [ "${UNISHELL_AUTOPSY_ENABLED:-0}" = "1" ] || return 0
  [ -n "$_AUTOPSY_LAST_CMD" ]               || return 0
  [ "$exit_code" -ne 0 ]                    || return 0

  local stderr_content=""
  if [ -f "${_AUTOPSY_STDERR:-}" ] && [ -s "$_AUTOPSY_STDERR" ]; then
    stderr_content="$(cat "$_AUTOPSY_STDERR" 2>/dev/null)"
    : >"$_AUTOPSY_STDERR" 2>/dev/null || true
  fi

  _unishell_autopsy_match "$_AUTOPSY_LAST_CMD" "$exit_code" "$stderr_content"
  _AUTOPSY_LAST_CMD=""   # consume — avoid repeating on next prompt
}

# ── Zsh hooks ─────────────────────────────────────────────────────────────────

# TRAPERR (= TRAPZERR) fires in Zsh immediately when any interactive command
# exits with a non-zero status — crucially, BEFORE any precmd hook runs.
# We only save the exit code here; analysis happens in _autopsy_zsh_precmd
# once the tee process has had a chance to flush stderr to the capture file.
_autopsy_define_trapzerr() {
  # Define using eval so that 'function TRAPZERR' is a proper Zsh function.
  eval '
function TRAPZERR() {
  local err=$?
  # Only save when autopsy is on and a real command was recorded.
  if [ "${UNISHELL_AUTOPSY_ENABLED:-0}" = "1" ] && [ -n "$_AUTOPSY_LAST_CMD" ]; then
    _AUTOPSY_SAVED_EXIT=$err
  fi
}
'
}

# Runs after every command (appended to precmd_functions).
# Reads _AUTOPSY_SAVED_EXIT — NOT $? — so p9k ordering cannot corrupt it.
_autopsy_zsh_precmd() {
  local exit_code="${_AUTOPSY_SAVED_EXIT:-0}"
  _AUTOPSY_SAVED_EXIT=0   # reset for next command
  [ "$exit_code" -ne 0 ] && _unishell_autopsy_hook "$exit_code"
}

# ── Hook enable / disable ─────────────────────────────────────────────────────

_unishell_autopsy_enable_hooks() {
  UNISHELL_AUTOPSY_ENABLED=1
  [ -f "${_AUTOPSY_STDERR:-}" ] || _autopsy_init_stderr_file

  if [ -n "${ZSH_VERSION:-}" ]; then
    autoload -Uz add-zsh-hook 2>/dev/null || true
    # preexec: capture command string before it runs.
    add-zsh-hook preexec _unishell_autopsy_debug 2>/dev/null || true
    # TRAPERR: save exit code immediately on failure (before p9k resets $?).
    _autopsy_define_trapzerr
    # precmd: read saved exit code and run analysis.
    add-zsh-hook precmd _autopsy_zsh_precmd 2>/dev/null || true
    # Stderr capture via tee — guarded so we never stack two redirections.
    if [ "${_AUTOPSY_STDERR_REDIRECTED:-0}" != "1" ]; then
      exec 2> >(tee "$_AUTOPSY_STDERR" >&2)
      _AUTOPSY_STDERR_REDIRECTED=1
    fi
  else
    # Bash: DEBUG trap captures command string; ERR trap fires on failure.
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
    add-zsh-hook -d precmd  _autopsy_zsh_precmd     2>/dev/null || true
    # Neutralise TRAPZERR without undefining it (undefining causes Zsh warnings).
    eval 'function TRAPZERR() { :; }'
  else
    trap - ERR DEBUG
  fi

  # Restore stderr to the terminal.
  if [ "${_AUTOPSY_STDERR_REDIRECTED:-0}" = "1" ]; then
    if [ -e /dev/tty ]; then
      exec 2>/dev/tty
    else
      exec 2>&1
    fi
    _AUTOPSY_STDERR_REDIRECTED=0
  fi

  [ -f "${_AUTOPSY_STDERR:-}" ] && rm -f "$_AUTOPSY_STDERR" 2>/dev/null || true
}

# ── Pattern matching engine ───────────────────────────────────────────────────

_unishell_autopsy_match() {
  local cmd="$1" exit_code="$2" stderr="$3"
  local combined="${stderr}${cmd}"

  [ -f "$_AUTOPSY_PATTERNS" ] || return

  local matched_cause="" matched_fix="" matched_learn=""

  while IFS=$'\t' read -r pattern_exit pattern_regex cause fix learn || [ -n "$pattern_exit" ]; do
    case "$pattern_exit" in "#"*|"") continue ;; esac
    if [ "$pattern_exit" != "*" ] && [ "$pattern_exit" != "$exit_code" ]; then
      continue
    fi
    if printf '%s\n' "$combined" | grep -aqE "$pattern_regex" 2>/dev/null; then
      local captured
      captured="$(printf '%s\n' "$combined" | grep -aoE "$pattern_regex" 2>/dev/null | head -1)"
      matched_cause="$cause"
      matched_fix="$(printf '%s' "$fix" | sed "s|\$1|$captured|g")"
      matched_learn="$learn"
      break
    fi
  done <"$_AUTOPSY_PATTERNS"

  [ -z "$matched_cause" ] && return

  printf "\n"
  printf "%b\n" "  ${RED}✖${NC}  ${BOLD}${_AUTOPSY_LAST_CMD}${NC}  exited ${YELLOW}${exit_code}${NC}"
  printf "\n"
  printf "%b\n" "  ${BLUE}🔎 Cause:${NC}   $matched_cause"

  if [ -n "$matched_fix" ] && [ "$matched_fix" != "-" ]; then
    printf "%b\n" "  ${GREEN}🔧 Fix:${NC}     ${BOLD}${matched_fix}${NC}"
    [ -n "$matched_learn" ] && printf "%b\n" "  ${CYAN}📚 Learn:${NC}   $matched_learn"
    printf "\n"
    printf "%b" "  Run the fix? (y/N): "
    local confirm; read -r confirm
    case "$confirm" in
      y|Y|yes|YES)
        printf "%b\n" "  ${GREEN}→${NC} ${matched_fix}"
        # SEC-1: run fix in a subshell, not via eval, to prevent injection.
        ( $matched_fix )
        ;;
    esac
  else
    [ -n "$matched_learn" ] && printf "%b\n" "  ${CYAN}📚 Learn:${NC}   $matched_learn"
  fi
  printf "\n"
}

# ── User-facing command ───────────────────────────────────────────────────────

autopsy() {
  local subcmd="${1:-status}"
  [ $# -gt 0 ] && shift

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
      [ -f "$_AUTOPSY_PATTERNS" ] && \
        count=$(grep -cv '^#\|^$' "$_AUTOPSY_PATTERNS" 2>/dev/null || echo 0)
      info "Patterns loaded: $count"
      ;;
    learn)
      local learn_cmd="${1:-}" learn_fix="${2:-}" learn_why="${3:-}"
      if [ -z "$learn_cmd" ] || [ -z "$learn_fix" ]; then
        err "Usage: autopsy learn \"failed-command\" \"fix-command\" [\"explanation\"]"
        return 1
      fi
      local user_patterns="$UNISHELL_HOME/autopsy/user-patterns.tsv"
      mkdir -p "$(dirname "$user_patterns")"
      local escaped
      escaped="$(printf '%s' "$learn_cmd" | sed 's/[.*+?^${}()|[\\]\\]/\\&/g')"
      printf "%s\t%s\t%s\t%s\t%s\n" \
        "*" "$escaped" "User-defined: $learn_cmd" "$learn_fix" "$learn_why" \
        >>"$user_patterns"
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

Autopsy is enabled automatically when UniShell loads.
EOF
      ;;
    *)
      err "Unknown subcommand: $subcmd. Run: autopsy help"
      return 1
      ;;
  esac
}

# ── Auto-enable on load ───────────────────────────────────────────────────────
# Fires when this file is first sourced by loader.sh.
# UNISHELL_AUTOPSY_ENABLED=0 before sourcing loader.sh to suppress.
if [ "${UNISHELL_AUTOPSY_ENABLED:-1}" != "0" ]; then
  _unishell_autopsy_enable_hooks
fi
