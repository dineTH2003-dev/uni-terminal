#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_HOME="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_HOME"
}
trap cleanup EXIT

export HOME="$TEST_HOME"
export SHELL="/bin/bash"
touch "$HOME/.bashrc"

"$ROOT_DIR/install.sh" >/dev/null
export PATH="$HOME/.unishell/bin:$PATH"

# shellcheck source=/dev/null
. "$HOME/.unishell/core/loader.sh"

unishell doctor >/dev/null
unishell init >/dev/null

mkassign dbms-lab-01 >/dev/null
[ -d "$HOME/workspace/university/dbms-lab-01/questions" ]
[ -d "$HOME/workspace/university/dbms-lab-01/answers" ]
[ -f "$HOME/workspace/university/dbms-lab-01/README.md" ]

mkproject demo-basic --basic >/dev/null
mkproject demo-python --python >/dev/null
mkproject demo-node --node >/dev/null

[ -f "$HOME/workspace/projects/demo-basic/.gitignore" ]
[ -f "$HOME/workspace/projects/demo-python/requirements.txt" ]
[ -f "$HOME/workspace/projects/demo-node/package.json" ]

"$ROOT_DIR/install.sh" >/dev/null
[ "$(grep -c 'source "$HOME/.unishell/core/loader.sh"' "$HOME/.bashrc")" -eq 1 ]

"$HOME/.unishell/uninstall.sh" >/dev/null
[ ! -d "$HOME/.unishell" ]
[ -d "$HOME/workspace" ]

printf "test-install.sh: ok\n"
