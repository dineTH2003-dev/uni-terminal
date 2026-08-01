#!/usr/bin/env bats

setup() {
  export REPO_ROOT="$BATS_TEST_DIRNAME/.."
  export BATS_TMPDIR="$REPO_ROOT/tests/tmp"
  mkdir -p "$BATS_TMPDIR"
  cd "$BATS_TMPDIR"
}

teardown() {
  rm -rf "$BATS_TMPDIR"
}

@test "predict enables without errors" {
  run bash -c "
    export UNISHELL_HOME='$REPO_ROOT'
    source '$REPO_ROOT/core/loader.sh'
    predict on 2>&1
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Predict enabled"* ]]
}

@test "predict disables without errors" {
  run bash -c "
    export UNISHELL_HOME='$REPO_ROOT'
    source '$REPO_ROOT/core/loader.sh'
    predict off 2>&1
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Predict disabled"* ]]
}

@test "predict prints help" {
  run bash -c "
    export UNISHELL_HOME='$REPO_ROOT'
    source '$REPO_ROOT/core/loader.sh'
    predict help 2>&1
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"predict — Real-time Git Predictive Auto-Suggestions"* ]]
}

@test "predict suggest: git push with no upstream" {
  # We test the logic function directly
  run bash -c "
    export UNISHELL_HOME='$REPO_ROOT'
    source '$REPO_ROOT/commands/predict.sh'
    git init -q repo1
    cd repo1
    git branch -m main
    READLINE_LINE='git push'
    _unishell_predict_suggest
    echo \"\$READLINE_LINE\"
  "
  [[ "$output" == *"git push --set-upstream origin main"* ]]
}

@test "predict suggest: uncommitted changes" {
  run bash -c "
    export UNISHELL_HOME='$REPO_ROOT'
    source '$REPO_ROOT/commands/predict.sh'
    git init -q repo2
    cd repo2
    touch test.txt
    git add test.txt
    READLINE_LINE=''
    _unishell_predict_suggest
    echo \"\$READLINE_LINE\"
  "
  [[ "$output" == *"git add ."* ]]
}
