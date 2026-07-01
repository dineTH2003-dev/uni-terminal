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

  local current_branch; current_branch=$(git branch --show-current 2>/dev/null)

  # Guard: warn before pushing directly to main/master/trunk/develop.
  case "$current_branch" in
    main|master|trunk|develop)
      printf "%b\n" "${YELLOW}[WARN]${NC} You are pushing directly to '${BOLD}${current_branch}${NC}${YELLOW}'."
      printf "%b\n" "         Pushing to protected branches is usually a mistake."
      printf "%b" "         Create a feature branch instead? (y/N): "
      local create_branch; read -r create_branch
      case "$create_branch" in
        y|Y|yes|YES)
          printf "%b" "         Branch name: "
          local new_branch; read -r new_branch
          if [ -z "$new_branch" ]; then
            err "Branch name cannot be empty."
            return 1
          fi
          git checkout -b "$new_branch"
          ok "Switched to '$new_branch'. Pushing this branch instead."
          current_branch="$new_branch"
          ;;
        *)
          printf "%b" "         Are you SURE you want to push to '$current_branch'? (yes/N): "
          local force_confirm; read -r force_confirm
          if [ "$force_confirm" != "yes" ]; then
            warn "Push cancelled."
            return 0
          fi
          ;;
      esac
      ;;
  esac

  local remote_url; remote_url=$(git remote get-url --push origin 2>/dev/null || true)
  [ -n "$remote_url" ] && info "Pushing to: $remote_url"
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
