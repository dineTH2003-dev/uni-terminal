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

UNISHELL_BIN="$HOME/.unishell/bin"
case ":$PATH:" in
  *":$UNISHELL_BIN:"*) ;;
  *) printf "UniShell bin path missing before off\n" >&2; exit 1 ;;
esac

unishell off >/dev/null

if alias ws >/dev/null 2>&1; then
  printf "ws alias still exists after unishell off\n" >&2
  exit 1
fi

if command -v mkproject >/dev/null 2>&1; then
  printf "mkproject still exists after unishell off\n" >&2
  exit 1
fi

case ":$PATH:" in
  *":$UNISHELL_BIN:"*) printf "UniShell bin path still exists after off\n" >&2; exit 1 ;;
esac

export PATH="$UNISHELL_BIN:$PATH"
# shellcheck source=/dev/null
. "$HOME/.unishell/core/loader.sh"

"$ROOT_DIR/install.sh" >/dev/null
[ "$(grep -c 'source "$HOME/.unishell/core/loader.sh"' "$HOME/.bashrc")" -eq 1 ]

"$HOME/.unishell/uninstall.sh" >/dev/null
[ ! -d "$HOME/.unishell" ]
[ -d "$HOME/workspace" ]

printf "test-install.sh: ok\n"
