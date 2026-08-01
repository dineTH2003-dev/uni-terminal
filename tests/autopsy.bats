#!/usr/bin/env bats
# tests/autopsy.bats — BATS test suite for the autopsy engine.
#
# Run with:  bats tests/autopsy.bats
# Install:   sudo apt install bats  OR  brew install bats-core
#
# Tests cover:
#   1. Syntax validity of all shell scripts
#   2. autopsy on/off lifecycle (no errors, no stacked tee processes)
#   3. Pattern matching for common student errors
#   4. No "shift count" error on zero-arg invocations (Zsh regression)
#   5. TSV file integrity (real tabs, no literal \t)

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
export UNISHELL_HOME="$REPO_ROOT"
export UNISHELL_TMPDIR="${BATS_TMPDIR:-/tmp}"

# ── 1. Syntax checks ──────────────────────────────────────────────────────────

@test "commands/autopsy.sh passes bash -n" {
  run bash -n "$REPO_ROOT/commands/autopsy.sh"
  [ "$status" -eq 0 ]
}

@test "commands/ghostsave.sh passes bash -n" {
  run bash -n "$REPO_ROOT/commands/ghostsave.sh"
  [ "$status" -eq 0 ]
}

@test "commands/drift.sh passes bash -n" {
  run bash -n "$REPO_ROOT/commands/drift.sh"
  [ "$status" -eq 0 ]
}

@test "commands/context.sh passes bash -n" {
  run bash -n "$REPO_ROOT/commands/context.sh"
  [ "$status" -eq 0 ]
}

@test "commands/broadcast.sh passes bash -n" {
  run bash -n "$REPO_ROOT/commands/broadcast.sh"
  [ "$status" -eq 0 ]
}

@test "commands/showme.sh passes bash -n" {
  run bash -n "$REPO_ROOT/commands/showme.sh"
  [ "$status" -eq 0 ]
}

@test "core/loader.sh passes bash -n" {
  run bash -n "$REPO_ROOT/core/loader.sh"
  [ "$status" -eq 0 ]
}

@test "core/config.sh passes bash -n" {
  run bash -n "$REPO_ROOT/core/config.sh"
  [ "$status" -eq 0 ]
}

@test "core/platform.sh passes bash -n" {
  run bash -n "$REPO_ROOT/core/platform.sh"
  [ "$status" -eq 0 ]
}

# ── 2. autopsy lifecycle ──────────────────────────────────────────────────────

@test "autopsy enables without errors" {
  run bash -i -c "
    export UNISHELL_HOME='$REPO_ROOT'
    source '$REPO_ROOT/core/loader.sh'
    autopsy on 2>&1
    echo \"exit:\$?\"
    echo \"enabled:\${UNISHELL_AUTOPSY_ENABLED}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Autopsy enabled"* ]]
  [[ "$output" == *"enabled:1"* ]]
}

@test "autopsy status shows enabled" {
  run bash -i -c "
    export UNISHELL_HOME='$REPO_ROOT'
    source '$REPO_ROOT/core/loader.sh'
    autopsy on 2>/dev/null
    autopsy status 2>&1
  "
  [[ "$output" == *"Autopsy is enabled"* ]]
  [[ "$output" == *"Plugins loaded"* ]]
}

@test "autopsy disables without errors" {
  run bash -i -c "
    export UNISHELL_HOME='$REPO_ROOT'
    source '$REPO_ROOT/core/loader.sh'
    autopsy on 2>/dev/null
    autopsy off 2>&1
    echo \"enabled:\${UNISHELL_AUTOPSY_ENABLED}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Autopsy disabled"* ]]
  [[ "$output" == *"enabled:0"* ]]
}

@test "autopsy does not stack tee processes on multiple enables" {
  run bash -i -c "
    export UNISHELL_HOME='$REPO_ROOT'
    source '$REPO_ROOT/core/loader.sh'
    autopsy on 2>/dev/null
    autopsy on 2>/dev/null  # second call must be a no-op
    echo \"redirected:\${_AUTOPSY_STDERR_REDIRECTED}\"
  "
  # Should still be 1, not 2 or more
  [[ "$output" == *"redirected:1"* ]]
}

# ── 3. Pattern matching ───────────────────────────────────────────────────────

@test "pattern: git invalid subcommand" {
  run bash -i -c "
    export UNISHELL_HOME='$REPO_ROOT'
    source '$REPO_ROOT/core/loader.sh'
    autopsy on 2>/dev/null
    git p
    echo 'DONE'
  " <<< "n"
  [[ "$output" == *"Cause:"* ]] || [[ "$output" == *"invalid git"* ]] || \
  [[ "$output" == *"git sub-command"* ]]
}


# ── 4. Shift regression (Zsh-style zero-arg call) ────────────────────────────

@test "autopsy with no args prints no 'shift count' error" {
  run bash -i -c "
    export UNISHELL_HOME='$REPO_ROOT'
    source '$REPO_ROOT/core/loader.sh'
    autopsy 2>&1
  "
  [[ "$output" != *"shift count must be"* ]]
  [[ "$output" != *"shift: can't shift"* ]]
}

@test "ghostsave with no args prints no 'shift count' error" {
  run bash -i -c "
    export UNISHELL_HOME='$REPO_ROOT'
    source '$REPO_ROOT/core/loader.sh'
    # ghostsave with no args (status)
    ghostsave 2>&1 || true
  "
  [[ "$output" != *"shift count must be"* ]]
}

@test "showme help prints no 'shift count' error" {
  run bash -i -c "
    export UNISHELL_HOME='$REPO_ROOT'
    source '$REPO_ROOT/core/loader.sh'
    showme help 2>&1
  "
  [[ "$output" != *"shift count must be"* ]]
}

# ── 5. TSV file integrity ─────────────────────────────────────────────────────

@test "plugin tsvs use real tabs (not literal backslash-t)" {
  # If any file has literal \t strings, grep will find them
  run bash -c "grep '\\\\t' $REPO_ROOT/autopsy/plugins/*.tsv | wc -l"
  # Should be 0 files with literal \t occurrences
  [ "$output" -eq 0 ]
}

@test "plugins have at least 15 patterns combined" {
  run bash -c "cat $REPO_ROOT/autopsy/plugins/*.tsv | grep -cv '^#\|^$'"
  [ "$output" -ge 15 ]
}

@test "every non-comment line in plugins has 5 tab-separated fields" {
  run bash -c "
    bad=0
    for file in $REPO_ROOT/autopsy/plugins/*.tsv; do
      while IFS=$'\\t' read -r f1 f2 f3 f4 f5 rest; do
        case \"\$f1\" in '#'*|'') continue ;; esac
        [ -z \"\$f5\" ] && bad=\$((bad+1))
      done < \"\$file\"
    done
    echo \$bad
  "
  [ "$output" -eq 0 ]
}
