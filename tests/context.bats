#!/usr/bin/env bats

# ── Setup & Teardown ─────────────────────────────────────────────────────────

setup() {
  export REPO_ROOT="$BATS_TEST_DIRNAME/.."

  # Create a fake project directory inside ~/dev so context's path guard passes
  export TEST_PROJECT="$HOME/dev/uni_test_context_$$"
  mkdir -p "$TEST_PROJECT"

  # Point context storage to a temp dir so tests don't pollute real data
  export UNISHELL_HOME="$BATS_TMPDIR/unishell_home_$$"
  export _CONTEXT_DIR="$UNISHELL_HOME/context"
  mkdir -p "$_CONTEXT_DIR"

  cd "$TEST_PROJECT"
}

teardown() {
  rm -rf "$TEST_PROJECT"
  rm -rf "$UNISHELL_HOME"
}

# Helper: load context.sh with helpers in a fresh subshell
_ctx() {
  bash -c "
    export UNISHELL_HOME='$UNISHELL_HOME'
    export _CONTEXT_DIR='$_CONTEXT_DIR'
    cd '$TEST_PROJECT'
    source '$REPO_ROOT/core/config.sh'
    source '$REPO_ROOT/commands/context.sh'
    $*
  "
}

# ── Basic Subcommand Tests ────────────────────────────────────────────────────

@test "context help shows all subcommands" {
  run _ctx "context help"
  [ "$status" -eq 0 ]
  [[ "$output" == *"log"*       ]]
  [[ "$output" == *"mark-setup"* ]]
  [[ "$output" == *"replay"*    ]]
  [[ "$output" == *"search"*    ]]
  [[ "$output" == *"clear"*     ]]
  [[ "$output" == *"projects"*  ]]
}

@test "context log shows warning when no history exists" {
  run _ctx "context log"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No history"* ]]
}

@test "context search fails with no term" {
  run _ctx "context search"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "context projects shows warning when empty" {
  run _ctx "context projects"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No project history"* ]]
}

@test "context unknown subcommand returns error" {
  run _ctx "context foobar"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown subcommand"* ]]
}

# ── Logging & Redaction Tests ─────────────────────────────────────────────────

@test "context log path is based on project directory name" {
  run _ctx "_context_log_path"
  [ "$status" -eq 0 ]
  # The path should contain the project directory name
  [[ "$output" == *"uni_test_context"* ]]
}

@test "_context_redact removes password= values" {
  run bash -c "
    source '$REPO_ROOT/core/config.sh'
    source '$REPO_ROOT/commands/context.sh'
    echo 'mysql -u root password=secret123' | _context_redact
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"REDACTED"* ]]
  [[ "$output" != *"secret123"* ]]
}

@test "_context_redact removes token= values" {
  run bash -c "
    source '$REPO_ROOT/core/config.sh'
    source '$REPO_ROOT/commands/context.sh'
    echo 'curl -H token=my_secret_token https://api.example.com' | _context_redact
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"REDACTED"* ]]
  [[ "$output" != *"my_secret_token"* ]]
}

@test "_context_redact leaves normal commands untouched" {
  run bash -c "
    source '$REPO_ROOT/core/config.sh'
    source '$REPO_ROOT/commands/context.sh'
    echo 'docker-compose up -d' | _context_redact
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "docker-compose up -d" ]]
}

# ── Log File Read / Write Tests ───────────────────────────────────────────────

@test "context log shows commands written to log file" {
  # Pre-populate a log file
  local log_path
  log_path=$(bash -c "
    export UNISHELL_HOME='$UNISHELL_HOME'
    export _CONTEXT_DIR='$_CONTEXT_DIR'
    cd '$TEST_PROJECT'
    source '$REPO_ROOT/core/config.sh'
    source '$REPO_ROOT/commands/context.sh'
    _context_log_path
  ")
  printf '%s\t%s\t%s\n' "2026-01-01T10:00:00Z" "$TEST_PROJECT" "npm run dev" >> "$log_path"
  printf '%s\t%s\t%s\n' "2026-01-01T10:05:00Z" "$TEST_PROJECT" "docker-compose up -d" >> "$log_path"

  run _ctx "context log"
  [ "$status" -eq 0 ]
  [[ "$output" == *"npm run dev"*          ]]
  [[ "$output" == *"docker-compose up -d"* ]]
}

@test "context search finds matching commands in log" {
  local log_path
  log_path=$(bash -c "
    export UNISHELL_HOME='$UNISHELL_HOME'
    export _CONTEXT_DIR='$_CONTEXT_DIR'
    cd '$TEST_PROJECT'
    source '$REPO_ROOT/core/config.sh'
    source '$REPO_ROOT/commands/context.sh'
    _context_log_path
  ")
  printf '%s\t%s\t%s\n' "2026-01-01T10:00:00Z" "$TEST_PROJECT" "npm run dev"          >> "$log_path"
  printf '%s\t%s\t%s\n' "2026-01-01T10:05:00Z" "$TEST_PROJECT" "docker-compose up -d" >> "$log_path"

  run _ctx "context search docker"
  [ "$status" -eq 0 ]
  [[ "$output" == *"docker-compose"* ]]
  [[ "$output" != *"npm run dev"*    ]]
}

@test "context search shows no results when term not found" {
  local log_path
  log_path=$(bash -c "
    export UNISHELL_HOME='$UNISHELL_HOME'
    export _CONTEXT_DIR='$_CONTEXT_DIR'
    cd '$TEST_PROJECT'
    source '$REPO_ROOT/core/config.sh'
    source '$REPO_ROOT/commands/context.sh'
    _context_log_path
  ")
  printf '%s\t%s\t%s\n' "2026-01-01T10:00:00Z" "$TEST_PROJECT" "npm run dev" >> "$log_path"

  run _ctx "context search kubernetes"
  [ "$status" -eq 0 ]
  [[ "$output" != *"npm run dev"* ]]
}

# ── Mark-Setup & Projects Tests ───────────────────────────────────────────────

@test "context mark-setup creates a .setup file" {
  local log_path setup_path
  log_path=$(bash -c "
    export UNISHELL_HOME='$UNISHELL_HOME'; export _CONTEXT_DIR='$_CONTEXT_DIR'
    cd '$TEST_PROJECT'; source '$REPO_ROOT/core/config.sh'; source '$REPO_ROOT/commands/context.sh'
    _context_log_path
  ")
  setup_path="${log_path%.log}.setup"
  printf '%s\t%s\t%s\n' "2026-01-01T10:00:00Z" "$TEST_PROJECT" "npm install"   >> "$log_path"
  printf '%s\t%s\t%s\n' "2026-01-01T10:01:00Z" "$TEST_PROJECT" "npm run dev"   >> "$log_path"

  run _ctx "context mark-setup 2"
  [ "$status" -eq 0 ]
  [ -f "$setup_path" ]
  grep -q "npm install" "$setup_path"
  grep -q "npm run dev" "$setup_path"
}

@test "context mark-setup fails when no log exists" {
  run _ctx "context mark-setup"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No command history"* ]]
}

@test "context projects lists projects after log is written" {
  local log_path
  log_path=$(bash -c "
    export UNISHELL_HOME='$UNISHELL_HOME'; export _CONTEXT_DIR='$_CONTEXT_DIR'
    cd '$TEST_PROJECT'; source '$REPO_ROOT/core/config.sh'; source '$REPO_ROOT/commands/context.sh'
    _context_log_path
  ")
  printf '%s\t%s\t%s\n' "2026-01-01T10:00:00Z" "$TEST_PROJECT" "npm run dev" >> "$log_path"

  run _ctx "context projects"
  [ "$status" -eq 0 ]
  # context projects replaces underscores with slashes in display, e.g. "dev/uni/test/context"
  [[ "$output" == *"cmds"* ]]
}
