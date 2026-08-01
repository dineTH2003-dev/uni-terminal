#!/usr/bin/env bash
# predict.sh — Real-time predictive Git auto-suggestion engine
#
# Binds to Ctrl+G. Analyzes the local git repository state and the current
# command buffer to instantly suggest or autocomplete the most logical
# next git command directly into the prompt.

_unishell_predict_suggest() {
  local buf
  if [ -n "${ZSH_VERSION:-}" ]; then
    buf="$BUFFER"
  else
    buf="$READLINE_LINE"
  fi

  # Only trigger if the buffer starts with git or is empty
  if [ -n "$buf" ] && [[ "$buf" != git* ]]; then
     return 0
  fi

  # Must be inside a git repo
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
     return 0
  fi

  local suggestion=""
  local git_dir
  git_dir="$(git rev-parse --git-dir 2>/dev/null)"

  # ── State 1: Rebase / Merge in progress ──
  if [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]; then
     suggestion="git rebase --continue"
  elif [ -f "$git_dir/MERGE_HEAD" ]; then
     suggestion="git merge --continue"
  
  # ── State 2: Push with no upstream ──
  elif [[ "$buf" == *"push"* ]]; then
     if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
        local b; b="$(git branch --show-current 2>/dev/null)"
        if [ -n "$b" ]; then
           suggestion="git push --set-upstream origin $b"
        else
           suggestion="git push origin HEAD"
        fi
     else
        suggestion="git push"
     fi

  # ── State 3: Detached HEAD ──
  elif ! git symbolic-ref -q HEAD >/dev/null 2>&1 && git rev-parse HEAD >/dev/null 2>&1; then
     suggestion="git checkout -b new-branch-name"
  
  # ── State 4: Uncommitted changes ──
  elif ! git diff-index --quiet HEAD -- 2>/dev/null; then
     if [[ "$buf" == *"commit"* ]]; then
        suggestion="git commit -m \"update\""
     elif [[ "$buf" == *"stash"* ]]; then
        suggestion="git stash"
     else
        suggestion="git add ."
     fi
  
  # ── State 5: Smart Flag Suggestions ──
  elif [[ "$buf" == "git push -f"* ]] || [[ "$buf" == "git push --force"* ]]; then
     suggestion="git push --force-with-lease"
  elif [[ "$buf" == *"commit -a"* ]]; then
     suggestion="git commit -am \"\""
  elif [[ "$buf" == *"commit -m"* ]]; then
     suggestion="git commit -m \"\""
  elif [[ "$buf" == *"log"* ]] && [[ "$buf" != *"--"* ]]; then
     suggestion="git log --oneline --graph --decorate"
  
  # ── State 6: Fallbacks and Typos ──
  elif [[ "$buf" == "git p" ]]; then
     # Check if ahead or behind
     if git status --porcelain -b 2>/dev/null | grep -q '\[ahead'; then
       suggestion="git push"
     else
       suggestion="git pull"
     fi
  elif [[ "$buf" == "git m" ]]; then
     suggestion="git merge "
  elif [[ "$buf" == "git c" ]]; then
     suggestion="git commit -m \"\""
  elif [[ "$buf" == "git b" ]]; then
     suggestion="git branch -a"
  elif [[ "$buf" == *"fetch"* ]]; then
     suggestion="git fetch --all --prune"
  else
     suggestion="git status"
  fi

  # ── Apply the suggestion ──
  if [ -n "$suggestion" ]; then
    if [ -n "${ZSH_VERSION:-}" ]; then
      BUFFER="$suggestion"
      CURSOR=${#BUFFER}
    else
      READLINE_LINE="$suggestion"
      READLINE_POINT=${#READLINE_LINE}
    fi
  fi
}

_unishell_predict_enable_hooks() {
  UNISHELL_PREDICT_ENABLED=1
  if [ -n "${ZSH_VERSION:-}" ]; then
    # In Zsh, bindkey requires the widget to be registered
    zle -N _unishell_predict_suggest 2>/dev/null || true
    bindkey '^G' _unishell_predict_suggest 2>/dev/null || true
  else
    # In Bash, bind -x executes a shell function
    bind -x '"\C-g": _unishell_predict_suggest' 2>/dev/null || true
  fi
}

_unishell_predict_disable_hooks() {
  UNISHELL_PREDICT_ENABLED=0
  if [ -n "${ZSH_VERSION:-}" ]; then
    bindkey -r '^G' 2>/dev/null || true
  else
    bind -r '\C-g' 2>/dev/null || true
  fi
}

# ── User-facing command ───────────────────────────────────────────────────────

predict() {
  local subcmd="${1:-help}"
  [ $# -gt 0 ] && shift

  case "$subcmd" in
    on|enable)
      _unishell_predict_enable_hooks
      printf "\033[0;32m[OK]\033[0m   Git Predict enabled. Press \033[1;33mCtrl+G\033[0m while typing to auto-complete.\n"
      ;;
    off|disable)
      _unishell_predict_disable_hooks
      printf "\033[0;32m[OK]\033[0m   Predict disabled.\n"
      ;;
    help|-h|--help)
      cat <<'EOF'
predict — Real-time Git Predictive Auto-Suggestions

  predict on          Enable Ctrl+G auto-suggestions
  predict off         Disable Ctrl+G auto-suggestions

How it works:
  When typing a command, press [Ctrl+G]. 
  Predict will analyze your repository state (merge conflicts, detached HEAD, 
  missing upstreams, etc.) and instantly auto-complete your command line!
EOF
      ;;
    *)
      printf "\033[0;31m[ERR]\033[0m  Unknown subcommand: %s. Run: predict help\n" "$subcmd" >&2
      return 1
      ;;
  esac
}

# Auto-enable on load
if [ "${UNISHELL_PREDICT_ENABLED:-1}" != "0" ]; then
  _unishell_predict_enable_hooks
fi
