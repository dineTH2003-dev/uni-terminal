#!/usr/bin/env bash

onboard() {
  local repo_url="${1:-}"

  if [ -z "$repo_url" ]; then
    err "Usage: onboard <git-repo-url>"
    return 1
  fi

  # Extract repo name from URL (e.g., git@github.com:user/project.git -> project)
  local repo_name
  repo_name=$(basename "$repo_url" .git)

  if [ -e "$repo_name" ]; then
    err "Directory '$repo_name' already exists in the current directory."
    return 1
  fi

  info "Cloning repository $repo_url..."
  if ! git clone "$repo_url" "$repo_name"; then
    err "Failed to clone repository."
    return 1
  fi

  cd "$repo_name" || return 1

  local project_type="Unknown"
  local start_cmd=""

  # Docker Setup
  if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ] || [ -f "compose.yml" ] || [ -f "compose.yaml" ]; then
    info "Docker Compose configuration detected."
    if unishell_confirm "Do you want to start Docker services in the background?"; then
      info "Starting Docker services..."
      if command -v docker-compose &>/dev/null; then
        docker-compose up -d || warn "Failed to start docker services."
      elif docker compose version &>/dev/null; then
        docker compose up -d || warn "Failed to start docker services."
      else
        warn "Docker Compose not found."
      fi
    fi
  fi

  # Environment Setup
  if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    cp .env.example .env
    info "Created .env from .env.example"
  elif [ -f ".env.template" ] && [ ! -f ".env" ]; then
    cp .env.template .env
    info "Created .env from .env.template"
  fi

  # Project Detection & Setup
  if [ -f "package.json" ]; then
    project_type="Node.js"
    info "Detected Node.js project. Installing dependencies..."
    if [ -f "yarn.lock" ]; then
      yarn install
      start_cmd="yarn dev"
    elif [ -f "pnpm-lock.yaml" ]; then
      pnpm install
      start_cmd="pnpm dev"
    elif [ -f "bun.lockb" ]; then
      bun install
      start_cmd="bun run dev"
    else
      npm install
      start_cmd="npm run dev"
    fi
    
    # DB Migrations for Node (Prisma)
    if [ -d "prisma" ] || grep -q "prisma" package.json 2>/dev/null; then
       info "Prisma ORM detected."
       if unishell_confirm "Do you want to run Prisma migrations and generate client?"; then
          if [ -f "yarn.lock" ]; then
            yarn prisma generate
            yarn prisma migrate dev || warn "Prisma migrate failed."
          elif [ -f "pnpm-lock.yaml" ]; then
            pnpm prisma generate
            pnpm prisma migrate dev || warn "Prisma migrate failed."
          else
            npx prisma generate
            npx prisma migrate dev || warn "Prisma migrate failed."
          fi
       fi
    fi

  elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    project_type="Python"
    info "Detected Python project."
    
    if unishell_confirm "Do you want to create a virtual environment (venv)?"; then
      info "Creating virtual environment in ./venv..."
      if command -v python3 &>/dev/null; then
        python3 -m venv venv || warn "Failed to create venv."
      else
        python -m venv venv || warn "Failed to create venv."
      fi
      
      # Source it for the remainder of this setup
      if [ -f "venv/bin/activate" ]; then
        # shellcheck source=/dev/null
        source venv/bin/activate
        info "Virtual environment activated for setup."
      fi
    fi

    if [ -f "requirements.txt" ]; then
      info "Installing dependencies from requirements.txt..."
      pip install -r requirements.txt
    fi

    # DB Migrations for Python (Django/Alembic)
    if [ -f "manage.py" ]; then
      start_cmd="python manage.py runserver"
      info "Django project detected."
      if unishell_confirm "Do you want to run Django migrations?"; then
        python manage.py migrate
      fi
    elif [ -f "alembic.ini" ]; then
      start_cmd="uvicorn main:app --reload"
      info "Alembic detected."
      if unishell_confirm "Do you want to run Alembic migrations?"; then
        alembic upgrade head
      fi
    else
      start_cmd="python main.py"
    fi

  elif [ -f "Cargo.toml" ]; then
    project_type="Rust"
    info "Detected Rust project. Building..."
    cargo build
    start_cmd="cargo run"

  elif [ -f "go.mod" ]; then
    project_type="Go"
    info "Detected Go project. Downloading modules..."
    go mod download
    start_cmd="go run ."
  fi

  # Custom onboarding script
  if [ -f ".unishell-onboard" ]; then
    info "Custom .unishell-onboard script detected. Executing..."
    if unishell_confirm "Are you sure you want to run the project's custom setup script?"; then
      bash .unishell-onboard
    fi
  fi

  ok "Project '$repo_name' ($project_type) ready!"
  if [ -n "$start_cmd" ]; then
    info "To start, run:"
    printf "  cd %s\n" "$repo_name"
    # If python venv
    if [ "$project_type" = "Python" ] && [ -d "venv" ]; then
      printf "  source venv/bin/activate\n"
    fi
    printf "  %s\n" "$start_cmd"
  fi
}
