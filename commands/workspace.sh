#!/usr/bin/env bash

unishell_init() {
  local dirs=(
    university
    projects
    devops
    experiments
    scripts
    learning
    open-source
    backups
  )

  mkdir -p "$WORKSPACE_DIR"
  ok "Workspace root ready: $WORKSPACE_DIR"

  local dir
  for dir in "${dirs[@]}"; do
    mkdir -p "$WORKSPACE_DIR/$dir"
    ok "Directory ready: $WORKSPACE_DIR/$dir"
  done
}
