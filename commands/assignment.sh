#!/usr/bin/env bash

mkassign() {
  local name="${1:-}"

  if ! unishell_valid_name "$name"; then
    err "Usage: mkassign assignment-name"
    err "Use letters, numbers, dots, underscores, and hyphens only."
    return 1
  fi

  local target="$WORKSPACE_DIR/university/$name"
  if [ -e "$target" ]; then
    warn "Assignment already exists: $target"
    return 1
  fi

  mkdir -p "$target/questions" "$target/answers" "$target/screenshots" "$target/references" "$target/submissions"

  local template="$UNISHELL_HOME/templates/assignment/README.md"
  if [ -f "$template" ]; then
    cp "$template" "$target/README.md"
    sed -i "s/{{ASSIGNMENT_NAME}}/$name/g" "$target/README.md"
    sed -i "s/{{DATE}}/$(date +%Y-%m-%d)/g" "$target/README.md"
  else
    printf "# %s\n\nCreated: %s\n" "$name" "$(date +%Y-%m-%d)" > "$target/README.md"
  fi

  ok "Created assignment: $target"
  info "Next: cd $target"
}
