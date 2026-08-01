# Contributing to UniShell

Thank you for your interest in contributing to UniShell!

## Project Structure

```
uni-terminal/
├── bin/unishell              CLI entry point
├── core/
│   ├── config.sh             Configuration, helpers, lazy-loader engine
│   ├── loader.sh             Module registration and PROMPT_COMMAND hooks
│   └── platform.sh           Cross-platform detection (linux/wsl/macos/gitbash)
├── commands/
│   ├── predict.sh            Predictive Git auto-suggestion engine
│   ├── drift.sh              Environment drift detector
│   ├── ghostsave.sh          Shadow commit system
│   ├── context.sh            Per-project command memory
│   ├── broadcast.sh          LAN terminal streaming
│   └── showme.sh             GUI transparency engine

├── showme/translations/
│   ├── fs.tsv                Filesystem event → command translations
│   └── dbus.tsv              D-Bus event → command translations
├── docs/
│   ├── installation.md
│   └── commands.md
├── install.sh
├── uninstall.sh
└── README.md
```

## How to Add Custom Predict Plugins (Docker, npm, etc.)

While the core project is 100% optimized for Git, you can easily add custom auto-suggestions for other tools (like Docker or Kubernetes) without modifying the core code.

1. Create a file in your user directory: `~/.unishell/predict.d/docker.sh`
2. Define a function named `_predict_plugin_match` that sets the `PLUGIN_SUGGESTION` variable.

**Example: `~/.unishell/predict.d/docker.sh`**
```bash
_predict_plugin_match() {
  local buf="$1"
  PLUGIN_SUGGESTION=""
  
  if [[ "$buf" == "docker p" ]]; then
     PLUGIN_SUGGESTION="docker ps -a"
  elif [[ "$buf" == "docker r" ]]; then
     PLUGIN_SUGGESTION="docker run -it --rm "
  fi
}
```
Whenever you press `Ctrl+G`, UniShell will instantly evaluate your custom plugins before falling back to the default Git logic!

## How to Add New Core Git Predict Logic

If you want to add new Git rules to the core project, edit `commands/predict.sh` and add new state checks to the Git logic block in `_unishell_predict_suggest()`. Ensure any git commands run instantly in the background (`2>/dev/null`) to keep typing latency at zero.

## How to Add a New D-Bus Translation

Edit `showme/translations/dbus.tsv` and add a line:

```
DBUS_INTERFACE	DBUS_MEMBER	BUS	COMMAND_TEMPLATE	DESCRIPTION
```

## Guidelines

- All code must be pure Bash (no Python, no Node.js, no compiled binaries)
- All features must work offline with zero internet dependency
- Use `${UNISHELL_TMPDIR:-/tmp}` instead of hardcoded `/dev/shm`
- Run `bash -n <file>` to syntax-check before committing
- Follow Conventional Commits for commit messages

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
