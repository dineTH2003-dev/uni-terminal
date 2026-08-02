#!/usr/bin/env bats

# ── Setup & Teardown ─────────────────────────────────────────────────────────

setup() {
  export REPO_ROOT="$BATS_TEST_DIRNAME/.."
  export TEST_REPO="$BATS_TMPDIR/ghostsave_test_$$"
  mkdir -p "$TEST_REPO"
  cd "$TEST_REPO"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"
  git checkout -q -b main 2>/dev/null || git checkout -q -b master 2>/dev/null || true
  echo "init" > file.txt
  git add file.txt
  git commit -q -m "initial commit"
}

teardown() {
  rm -rf "$TEST_REPO"
}

# Helper: source ghostsave with the loader helpers (ok/info/err/warn)
_load_ghostsave() {
  source "$REPO_ROOT/core/config.sh" 2>/dev/null
  source "$REPO_ROOT/commands/ghostsave.sh"
}

# ── Basic Subcommand Tests ────────────────────────────────────────────────────

@test "ghostsave enable prints confirmation" {
  cd "$TEST_REPO"
  run bash -c "source '$REPO_ROOT/core/config.sh'; source '$REPO_ROOT/commands/ghostsave.sh'; ghostsave on"
  [ "$status" -eq 0 ]
  [[ "$output" == *"enabled"* ]]
}

@test "ghostsave disable prints confirmation" {
  cd "$TEST_REPO"
  run bash -c "source '$REPO_ROOT/core/config.sh'; source '$REPO_ROOT/commands/ghostsave.sh'; ghostsave off"
  [ "$status" -eq 0 ]
  [[ "$output" == *"disabled"* ]]
}

@test "ghostsave help shows all subcommands" {
  cd "$TEST_REPO"
  run bash -c "source '$REPO_ROOT/core/config.sh'; source '$REPO_ROOT/commands/ghostsave.sh'; ghostsave help"
  [ "$status" -eq 0 ]
  [[ "$output" == *"enable"*       ]]
  [[ "$output" == *"disable"*      ]]
  [[ "$output" == *"tick"*         ]]
  [[ "$output" == *"status"*       ]]
  [[ "$output" == *"restore"*      ]]
  [[ "$output" == *"squash"*       ]]
  [[ "$output" == *"purge"*        ]]
  [[ "$output" == *"interval"*     ]]
}

@test "ghostsave status shows 0 ghosts initially" {
  cd "$TEST_REPO"
  run bash -c "source '$REPO_ROOT/core/config.sh'; source '$REPO_ROOT/commands/ghostsave.sh'; ghostsave status"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Shadow commits"*"0"* ]]
}

@test "ghostsave fails outside a git repo" {
  cd /tmp
  run bash -c "source '$REPO_ROOT/core/config.sh'; source '$REPO_ROOT/commands/ghostsave.sh'; ghostsave status"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Not inside a git repository"* ]]
}

# ── Tick / Snapshot Tests ─────────────────────────────────────────────────────

@test "ghostsave tick creates a ghost when there are changes" {
  cd "$TEST_REPO"
  echo "new change" >> file.txt
  run bash -c "
    source '$REPO_ROOT/core/config.sh'
    source '$REPO_ROOT/commands/ghostsave.sh'
    _GHOST_LAST_TICK=0
    _unishell_ghost_tick
    branch=\$(git branch --show-current)
    git rev-parse -q --verify refs/ghosts/\$branch
  "
  [ "$status" -eq 0 ]
}

@test "ghostsave tick is a no-op when working tree is clean" {
  cd "$TEST_REPO"
  run bash -c "
    source '$REPO_ROOT/core/config.sh'
    source '$REPO_ROOT/commands/ghostsave.sh'
    _GHOST_LAST_TICK=0
    _unishell_ghost_tick
    branch=\$(git branch --show-current)
    git rev-parse -q --verify refs/ghosts/\$branch && echo 'found' || echo 'empty'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"empty"* ]]
}

@test "ghostsave tick is throttled by interval" {
  cd "$TEST_REPO"
  echo "change" >> file.txt
  run bash -c "
    source '$REPO_ROOT/core/config.sh'
    source '$REPO_ROOT/commands/ghostsave.sh'
    _GHOST_INTERVAL=9999
    _GHOST_LAST_TICK=\$(date +%s)
    _unishell_ghost_tick   # should be skipped due to throttle
    branch=\$(git branch --show-current)
    git rev-parse -q --verify refs/ghosts/\$branch && echo 'found' || echo 'empty'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"empty"* ]]
}

@test "ghostsave tick makes multiple ghosts chained correctly" {
  cd "$TEST_REPO"
  run bash -c "
    source '$REPO_ROOT/core/config.sh'
    source '$REPO_ROOT/commands/ghostsave.sh'
    echo 'change1' >> file.txt
    _GHOST_LAST_TICK=0; _unishell_ghost_tick
    echo 'change2' >> file.txt
    _GHOST_LAST_TICK=0; _unishell_ghost_tick
    branch=\$(git branch --show-current)
    git rev-list refs/ghosts/\$branch --count
  "
  [ "$status" -eq 0 ]
  # 2 ghosts + the initial HEAD commit = 3 in the chain
  [ "$output" -ge 2 ]
}

# ── Interval Subcommand Tests ─────────────────────────────────────────────────

@test "ghostsave interval shows current interval with no args" {
  cd "$TEST_REPO"
  run bash -c "source '$REPO_ROOT/core/config.sh'; source '$REPO_ROOT/commands/ghostsave.sh'; ghostsave interval"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Current snapshot interval"* ]]
}

@test "ghostsave interval updates the interval variable" {
  cd "$TEST_REPO"
  run bash -c "
    source '$REPO_ROOT/core/config.sh'
    source '$REPO_ROOT/commands/ghostsave.sh'
    ghostsave interval 300
    echo \"\$_GHOST_INTERVAL\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"300"* ]]
}

@test "ghostsave interval rejects values below 30 seconds" {
  cd "$TEST_REPO"
  run bash -c "source '$REPO_ROOT/core/config.sh'; source '$REPO_ROOT/commands/ghostsave.sh'; ghostsave interval 10"
  [ "$status" -ne 0 ]
  [[ "$output" == *"30 seconds"* ]]
}

@test "ghostsave interval rejects non-numeric values" {
  cd "$TEST_REPO"
  run bash -c "source '$REPO_ROOT/core/config.sh'; source '$REPO_ROOT/commands/ghostsave.sh'; ghostsave interval abc"
  [ "$status" -ne 0 ]
}

# ── Purge Test ────────────────────────────────────────────────────────────────

@test "ghostsave purge clears ghost history" {
  cd "$TEST_REPO"
  run bash -c "
    source '$REPO_ROOT/core/config.sh'
    source '$REPO_ROOT/commands/ghostsave.sh'
    echo 'change' >> file.txt
    _GHOST_LAST_TICK=0
    _unishell_ghost_tick
    ghostsave purge 2>&1
    branch=\$(git branch --show-current)
    git rev-parse -q --verify refs/ghosts/\$branch && echo 'still_exists' || echo 'gone'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"gone"* ]]
}
