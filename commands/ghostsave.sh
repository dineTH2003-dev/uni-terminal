#!/usr/bin/env bash
# ghostsave.sh — Invisible auto-save shadow commit system.
#
# Creates local-only git commits on refs/ghosts/<branch> — completely invisible
# to 'git log', 'git push', and teammates. Fires on every prompt change when
# enabled. 'ghostsave squash' collapses all ghosts into one clean real commit.
# Zero daemon. Zero network. Zero manual rebasing.

_GHOST_INTERVAL="${UNISHELL_GHOST_INTERVAL:-900}"  # seconds between auto-ticks (default 15m)
_GHOST_LAST_TICK=0

# ── Passive PROMPT_COMMAND hook (replaces no-op stub from loader) ────────────

_unishell_ghost_tick() {
  # Only inside a git repo.
  [ -d ".git" ] || git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return

  # Throttle: only run if enough time has elapsed since last ghost.
  local now; now=$(date +%s)
  if (( now - _GHOST_LAST_TICK < _GHOST_INTERVAL )); then
    return
  fi

  # Only if there are uncommitted changes.
  git diff --quiet HEAD 2>/dev/null && git diff --cached --quiet 2>/dev/null && return

  local branch; branch=$(git branch --show-current 2>/dev/null)
  [ -z "$branch" ] && return  # Detached HEAD — skip.

  local ref="refs/ghosts/$branch"

  # Build the tree object from the current working state.
  # We stage everything to a temporary index, not the real one.
  local orig_index="${GIT_INDEX_FILE:-$(git rev-parse --git-dir)/index}"
  local tmp_index; tmp_index=$(mktemp "${TMPDIR:-/tmp}/unishell_ghost_XXXXXX")

  GIT_INDEX_FILE="$tmp_index" git read-tree HEAD 2>/dev/null || { rm -f "$tmp_index"; return; }
  GIT_INDEX_FILE="$tmp_index" git add -A 2>/dev/null || { rm -f "$tmp_index"; return; }
  local tree; tree=$(GIT_INDEX_FILE="$tmp_index" git write-tree 2>/dev/null)
  rm -f "$tmp_index"
  [ -z "$tree" ] && return

  # Find parent: last ghost commit or HEAD.
  local parent; parent=$(git rev-parse "$ref" 2>/dev/null || git rev-parse HEAD 2>/dev/null)

  # Write the ghost commit.
  local ghost
  ghost=$(git commit-tree "$tree" ${parent:+-p "$parent"} \
    -m "ghost: $(date '+%Y-%m-%d %H:%M:%S') [auto]" 2>/dev/null)
  [ -z "$ghost" ] && return

  git update-ref "$ref" "$ghost" 2>/dev/null
  _GHOST_LAST_TICK=$now
}

# ── Restore helper ───────────────────────────────────────────────────────────

_ghost_list_commits() {
  local branch="$1"
  local ref="refs/ghosts/$branch"
  git rev-list --no-walk=unsorted "$ref" 2>/dev/null | while read -r sha; do
    local msg; msg=$(git log -1 --format="%ar — %s" "$sha" 2>/dev/null)
    printf "%s\t%s\n" "$sha" "$msg"
  done | head -20
}

# ── User-facing command ──────────────────────────────────────────────────────

ghostsave() {
  local subcmd="${1:-status}"
  shift || true

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    err "Not inside a git repository."
    return 1
  fi

  local branch; branch=$(git branch --show-current 2>/dev/null)
  local ref="refs/ghosts/$branch"

  case "$subcmd" in
    enable|on)
      UNISHELL_GHOST_ENABLED=1
      export UNISHELL_GHOST_ENABLED
      ok "Ghostsave enabled — auto-snapshotting every ${_GHOST_INTERVAL}s for branch '${branch}'."
      info "Shadow commits are invisible to 'git log' and 'git push'."
      ;;
    disable|off)
      UNISHELL_GHOST_ENABLED=0
      ok "Ghostsave disabled for this session."
      ;;
    tick|now)
      # Force an immediate ghost commit regardless of interval.
      local saved_tick=$_GHOST_LAST_TICK
      _GHOST_LAST_TICK=0
      _unishell_ghost_tick
      if [ "$_GHOST_LAST_TICK" -gt "$saved_tick" ]; then
        ok "Ghost snapshot created."
      else
        info "No changes to snapshot."
      fi
      ;;
    status)
      local ghost_count=0
      ghost_count=$(git rev-list "$ref" --count 2>/dev/null || echo 0)
      if [ "${UNISHELL_GHOST_ENABLED:-0}" = "1" ]; then
        ok "Ghostsave is enabled (branch: $branch, interval: ${_GHOST_INTERVAL}s)"
      else
        warn "Ghostsave is disabled. Run: ghostsave enable"
      fi
      info "Shadow commits on '$branch': $ghost_count"
      if [ "$ghost_count" -gt 0 ]; then
        info "Latest ghosts:"
        git log --oneline --no-walk=unsorted "$ref" 2>/dev/null | head -5 | sed 's/^/  /'
      fi
      ;;
    restore)
      if ! git rev-parse "$ref" >/dev/null 2>&1; then
        warn "No ghost history for branch '$branch'."
        return 1
      fi

      info "Ghost history for branch '${branch}':"
      local i=1
      local shas=()
      while IFS=$'\t' read -r sha msg; do
        printf "  %d) %s\n" "$i" "$msg"
        shas+=("$sha")
        (( i++ ))
      done < <(_ghost_list_commits "$branch")

      if [ "${#shas[@]}" -eq 0 ]; then
        warn "No ghost commits found."
        return 1
      fi

      printf "\nRestore which ghost? (1-%d, or q to cancel): " "${#shas[@]}"
      local choice; read -r choice
      case "$choice" in
        q|Q|"") warn "Cancelled."; return 0 ;;
      esac

      if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#shas[@]}" ]; then
        err "Invalid selection."
        return 1
      fi

      local target_sha="${shas[$((choice-1))]}"
      warn "This will restore your working tree to ghost commit $target_sha."
      printf "Your current uncommitted changes will be stashed first. Continue? (y/N): "
      local confirm; read -r confirm
      case "$confirm" in
        y|Y|yes|YES)
          git stash push -m "ghostsave: pre-restore stash $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null || true
          git checkout "$target_sha" -- . 2>/dev/null
          ok "Working tree restored from ghost: $target_sha"
          info "Your previous changes are in 'git stash list'."
          ;;
        *) warn "Cancelled." ;;
      esac
      ;;
    squash)
      local commit_msg="${1:-}"
      if [ -z "$commit_msg" ]; then
        err "Usage: ghostsave squash \"your commit message\""
        return 1
      fi

      if ! git rev-parse "$ref" >/dev/null 2>&1; then
        warn "No ghost history for branch '$branch'. Nothing to squash."
        return 1
      fi

      local ghost_count
      ghost_count=$(git rev-list "$ref" --count 2>/dev/null || echo 0)
      warn "This will squash $ghost_count ghost commit(s) into one real commit: \"$commit_msg\""
      printf "Continue? (y/N): "
      local confirm; read -r confirm
      case "$confirm" in
        y|Y|yes|YES) ;;
        *) warn "Cancelled."; return 0 ;;
      esac

      # Get the tree from the most recent ghost.
      local ghost_tip; ghost_tip=$(git rev-parse "$ref" 2>/dev/null)
      local squash_tree; squash_tree=$(git rev-parse "${ghost_tip}^{tree}" 2>/dev/null)

      # Apply the tree to real working index.
      git checkout "$ghost_tip" -- . 2>/dev/null

      # Make the real commit.
      git add -A
      git commit -m "$commit_msg"

      # Clean up ghost refs.
      git update-ref -d "$ref" 2>/dev/null
      ok "✓ $ghost_count ghost commit(s) squashed into one clean commit: \"$commit_msg\""
      info "Ghost history cleared. Remote is clean."
      ;;
    purge)
      if git rev-parse "$ref" >/dev/null 2>&1; then
        git update-ref -d "$ref"
        ok "Ghost history purged for branch '$branch'."
      else
        warn "No ghost history to purge."
      fi
      ;;
    help|-h|--help)
      cat <<'EOF'
ghostsave — invisible auto-save shadow commit system

  ghostsave enable         Start auto-snapshotting every 15 minutes
  ghostsave disable        Stop auto-snapshotting this session
  ghostsave tick           Force an immediate ghost snapshot now
  ghostsave status         Show ghost count and recent ghost commits
  ghostsave restore        Interactively restore from a past ghost snapshot
  ghostsave squash "msg"   Collapse all ghosts into one clean real commit
  ghostsave purge          Delete all ghost history for current branch

Ghost commits live in refs/ghosts/<branch> — invisible to 'git log',
'git push', and all remote operations. They are purely local safety nets.
EOF
      ;;
    *)
      err "Unknown subcommand: $subcmd. Run: ghostsave help"
      return 1
      ;;
  esac
}
