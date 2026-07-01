#!/usr/bin/env bash

UNISHELL_LOADER_LOADED=1

if [ -n "${BASH_VERSION:-}" ]; then
  _unishell_loader_path="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  _unishell_loader_path="${(%):-%x}"
else
  _unishell_loader_path="$0"
fi

case "$_unishell_loader_path" in
  */*) UNISHELL_HOME="$(cd "$(dirname "$_unishell_loader_path")/.." && pwd -P 2>/dev/null)" ;;
  *) UNISHELL_HOME="$HOME/.unishell" ;;
esac
export UNISHELL_HOME

_unishell_source_file() {
  if [ -f "$1" ]; then
    if [ -n "${ZSH_VERSION:-}" ]; then
      setopt localoptions no_aliases
    fi

    # shellcheck source=/dev/null
    . "$1"
  fi
}

_unishell_clear_command_aliases() {
  unalias unishell uniexit mkassign mkproject openproj cdf editfile jump \
    gstatus gsave gpush glog gnew gundo sysinfo ports myip diskcheck \
    memcheck service-check docker-clean 2>/dev/null || true
}

_unishell_source_file "$UNISHELL_HOME/core/config.sh"
_unishell_clear_command_aliases
_unishell_source_file "$UNISHELL_HOME/core/aliases.sh"
_unishell_source_file "$UNISHELL_HOME/integrations/fzf.sh"
_unishell_source_file "$UNISHELL_HOME/integrations/zoxide.sh"

# ── Lazy-load all command modules (zero RAM cost until first use) ─────────────
_unishell_lazy workspace  unishell_init
_unishell_lazy assignment mkassign
_unishell_lazy project    mkproject whatshere
_unishell_lazy navigation openproj cdf editfile jump
_unishell_lazy git        gstatus gsave gpush glog gnew gundo
_unishell_lazy system     sysinfo ports myip diskcheck memcheck service-check docker-clean killport
_unishell_lazy tools      unishell_tools unishell_install_tools
_unishell_lazy doctor     unishell_doctor
_unishell_lazy onboard    onboard
_unishell_lazy autopsy    autopsy
_unishell_lazy drift      drift
_unishell_lazy ghostsave  ghostsave
_unishell_lazy context    context
_unishell_lazy broadcast  broadcast

# ── Register PROMPT_COMMAND hooks for passive background features ─────────────
# These hooks are tiny — they only fire meaningful logic when state changes.
_unishell_prompt_hooks() {
  # 1. Ghost-save tick: auto-snapshot git state if enabled.
  # Costs ~1 string comparison when idle.
  if [ "${UNISHELL_GHOST_ENABLED:-0}" = "1" ] && [ -d "${PWD}/.git" ]; then
    _unishell_ghost_tick 2>/dev/null || true
  fi

  # 2 & 3. Drift check + Context hook: only on directory change.
  if [ "$PWD" != "${UNISHELL_LAST_DIR:-}" ]; then
    UNISHELL_LAST_DIR="$PWD"
    if [ -f "$UNISHELL_HOME/drifts/$(basename "$PWD").snap" ]; then
      _unishell_drift_hook 2>/dev/null || true
    fi
    _unishell_context_hook 2>/dev/null || true
  fi
}

# Register into PROMPT_COMMAND (Bash) or precmd (Zsh)
if [ -n "${ZSH_VERSION:-}" ]; then
  autoload -Uz add-zsh-hook 2>/dev/null || true
  add-zsh-hook precmd _unishell_prompt_hooks 2>/dev/null || true
else
  case "${PROMPT_COMMAND:-}" in
    *_unishell_prompt_hooks*) ;;
    *) PROMPT_COMMAND="_unishell_prompt_hooks${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
  esac
fi

# No-op stubs so PROMPT_COMMAND never errors before a v2 module first-loads.
_unishell_ghost_tick()   { :; }
_unishell_drift_hook()   { :; }
_unishell_context_hook() { :; }

unset -f _unishell_source_file _unishell_clear_command_aliases
unset _unishell_loader_path
