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

# ── whatshere ────────────────────────────────────────────────────────────────
# Fingerprints the current directory: detects project type, available scripts,
# .env status, docker, and git state. Pure find/grep/awk — under 100ms.

whatshere() {
  local dir="${1:-.}"
  printf "\n%b\n" "${BOLD}📂 $(pwd)${NC}"
  printf "──────────────────────────────────────────────────\n\n"

  local project_type="" project_detail="" start_hint=""

  # ── Project type detection ───────────────────────────────────────────────
  if [ -f "$dir/package.json" ]; then
    project_type="Node.js"
    local pkg; pkg=$(cat "$dir/package.json" 2>/dev/null)
    if echo "$pkg" | grep -q '"next"'; then project_detail="Next.js"
    elif echo "$pkg" | grep -q '"vite"'; then project_detail="Vite"
    elif echo "$pkg" | grep -q '"express"'; then project_detail="Express"
    elif echo "$pkg" | grep -q '"react"'; then project_detail="React"
    elif echo "$pkg" | grep -q '"fastify"'; then project_detail="Fastify"
    fi
    local pm="npm"
    [ -f "$dir/yarn.lock" ]     && pm="yarn"
    [ -f "$dir/pnpm-lock.yaml" ] && pm="pnpm"
    [ -f "$dir/bun.lockb" ]     && pm="bun"
    local scripts; scripts=$(echo "$pkg" | grep -oE '"[a-zA-Z:_-]+"' | tr -d '"' | awk 'NR>1' | head -6 | tr '\n' '|' | sed 's/|$//')
    printf "%b\n" "  ${GREEN}📦 Node.js${project_detail:+ ($project_detail)}${NC}"
    [ -n "$scripts" ] && printf "%b\n" "  ${BLUE}📋 Scripts:${NC}    $pm run { $scripts }"
    start_hint="$pm run dev"

  elif [ -f "$dir/requirements.txt" ] || [ -f "$dir/pyproject.toml" ] || [ -f "$dir/setup.py" ]; then
    local py_extra=""
    grep -qi flask "$dir/requirements.txt" 2>/dev/null   && py_extra=" — Flask"
    grep -qi django "$dir/requirements.txt" 2>/dev/null  && py_extra=" — Django"
    grep -qi fastapi "$dir/requirements.txt" 2>/dev/null && py_extra=" — FastAPI"
    printf "%b\n" "  ${GREEN}🐍 Python${py_extra}${NC}"
    start_hint="python main.py"

  elif [ -f "$dir/Cargo.toml" ]; then
    local crate; crate=$(grep '^name' "$dir/Cargo.toml" 2>/dev/null | head -1 | awk -F'"' '{print $2}')
    printf "%b\n" "  ${GREEN}🦀 Rust${crate:+ — $crate}${NC}"
    start_hint="cargo run"

  elif [ -f "$dir/go.mod" ]; then
    local mod; mod=$(head -1 "$dir/go.mod" 2>/dev/null | awk '{print $2}')
    printf "%b\n" "  ${GREEN}🐹 Go${mod:+ — $mod}${NC}"
    start_hint="go run ."

  elif [ -f "$dir/Makefile" ]; then
    local targets; targets=$(grep '^[a-zA-Z][^:]*:' "$dir/Makefile" 2>/dev/null | cut -d: -f1 | head -5 | tr '\n' '|' | sed 's/|$//')
    printf "%b\n" "  ${GREEN}🔧 Makefile${NC}${targets:+ — targets: $targets}"
    start_hint="make"

  else
    printf "%b\n" "  ${YELLOW}❓ Unknown type${NC} — no package.json, requirements.txt, Cargo.toml, or go.mod"
  fi

  printf "\n"

  # ── .env status ──────────────────────────────────────────────────────────
  if [ -f "$dir/.env" ]; then
    local kc; kc=$(grep -cv '^\s*#\|^\s*$' "$dir/.env" 2>/dev/null || echo 0)
    printf "%b\n" "  ${GREEN}🔑 .env:${NC}       found ($kc keys)"
  elif [ -f "$dir/.env.example" ]; then
    printf "%b\n" "  ${YELLOW}🔑 .env:${NC}       missing — run: cp .env.example .env"
    local db_keys; db_keys=$(grep -iE 'DATABASE_URL|DB_HOST|POSTGRES|MYSQL|MONGO|REDIS' "$dir/.env.example" 2>/dev/null | cut -d= -f1 | head -3 | tr '\n' ', ' | sed 's/,$//')
    [ -n "$db_keys" ] && printf "%b\n" "  ${CYAN}🗄️  DB keys:${NC}    $db_keys"
  fi

  # ── Docker ────────────────────────────────────────────────────────────────
  if [ -f "$dir/docker-compose.yml" ] || [ -f "$dir/docker-compose.yaml" ]; then
    printf "%b\n" "  ${BLUE}🐳 Docker:${NC}     docker-compose.yml — run: docker-compose up"
  elif [ -f "$dir/Dockerfile" ]; then
    printf "%b\n" "  ${BLUE}🐳 Docker:${NC}     Dockerfile found"
  fi

  printf "\n"

  # ── Git state ─────────────────────────────────────────────────────────────
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local branch; branch=$(git branch --show-current 2>/dev/null)
    local uc; uc=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
    local ahead; ahead=$(git rev-list "@{u}..HEAD" --count 2>/dev/null || echo 0)
    local behind; behind=$(git rev-list "HEAD..@{u}" --count 2>/dev/null || echo 0)
    local gs="$branch"
    [ "$uc" -gt 0 ]     && gs="${gs}, ${uc} uncommitted"
    [ "$ahead" -gt 0 ]  && gs="${gs}, ${ahead} ahead"
    [ "$behind" -gt 0 ] && gs="${gs}, ${behind} behind"
    printf "%b\n" "  ${GREEN}🌿 Git:${NC}        $gs"
  else
    printf "%b\n" "  ${YELLOW}🌿 Git:${NC}        not initialised — run: git init"
  fi

  printf "\n"
  [ -n "$start_hint" ] && printf "%b\n\n" "  ${CYAN}⚡ Start:${NC}      ${BOLD}$start_hint${NC}"
}
