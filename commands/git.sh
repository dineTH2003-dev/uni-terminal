#!/usr/bin/env bash

_unishell_require_git_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    err "Not inside a Git repository."
    return 1
  fi
}

gstatus() {
  _unishell_require_git_repo || return 1

  local output
  output="$(git -c color.status=always status --short)"
  if [ -n "$output" ]; then
    printf "%s\n" "$output"
  else
    ok "Working tree clean"
  fi
}

gsave() {
  _unishell_require_git_repo || return 1

  local message="$*"
  if [ -z "$message" ]; then
    err 'Usage: gsave "commit message"'
    return 1
  fi

  git add .
  git commit -m "$message"
}

gpush() {
  _unishell_require_git_repo || return 1

  local remote_url
  remote_url="$(git remote get-url --push origin 2>/dev/null || true)"

  if [ -n "$remote_url" ]; then
    info "Pushing to: $remote_url"
  else
    warn "No origin remote configured."
  fi

  git push
}

glog() {
  _unishell_require_git_repo || return 1
  git log --oneline --graph --decorate -20
}

gnew() {
  _unishell_require_git_repo || return 1

  local branch="${1:-}"
  if [ -z "$branch" ]; then
    err "Usage: gnew branch-name"
    return 1
  fi

  git checkout -b "$branch"
}

gundo() {
  _unishell_require_git_repo || return 1

  warn "This will undo your last commit. Your changes stay in the working tree."
  printf "Continue? (y/N): "

  local confirm
  read -r confirm

  case "$confirm" in
    y|Y|yes|YES)
      git reset --soft HEAD~1
      ok "Last commit undone. Changes are still staged."
      ;;
    *)
      warn "Cancelled."
      ;;
  esac
}
