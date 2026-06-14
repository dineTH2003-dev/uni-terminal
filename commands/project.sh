#!/usr/bin/env bash

mkproject() {
  local name="${1:-}"
  local template_flag="${2:---basic}"

  if ! unishell_valid_name "$name"; then
    err "Usage: mkproject project-name --basic|--python|--node"
    err "Use letters, numbers, dots, underscores, and hyphens only."
    return 1
  fi

  local template_name
  case "$template_flag" in
    --basic) template_name="basic" ;;
    --python) template_name="python" ;;
    --node) template_name="node" ;;
    *)
      err "Unknown template: $template_flag"
      err "Usage: mkproject project-name --basic|--python|--node"
      return 1
      ;;
  esac

  local target="$WORKSPACE_DIR/projects/$name"
  if [ -e "$target" ]; then
    warn "Project already exists: $target"
    return 1
  fi

  local template_dir="$UNISHELL_HOME/templates/$template_name"
  if [ ! -d "$template_dir" ]; then
    err "Template not found: $template_name"
    return 1
  fi

  mkdir -p "$target"
  cp -R "$template_dir/." "$target/"

  if [ -f "$target/README.md" ]; then
    sed -i "s/{{PROJECT_NAME}}/$name/g" "$target/README.md"
    sed -i "s/{{DATE}}/$(date +%Y-%m-%d)/g" "$target/README.md"
  fi

  if [ -f "$target/package.json" ]; then
    sed -i "s/{{PROJECT_NAME}}/$name/g" "$target/package.json"
  fi

  ok "Created $template_name project: $target"
  info "Next: cd $target && git init"
}
