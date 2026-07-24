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
│   ├── autopsy.sh            Error post-mortem engine
│   ├── drift.sh              Environment drift detector
│   ├── ghostsave.sh          Shadow commit system
│   ├── context.sh            Per-project command memory
│   ├── broadcast.sh          LAN terminal streaming
│   └── showme.sh             GUI transparency engine
├── autopsy/
│   └── patterns.tsv          Error pattern database
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

## How to Add a New Error Pattern

Edit `autopsy/patterns.tsv` and add a line:

```
EXIT_CODE	STDERR_REGEX	FIX_COMMAND	EXPLANATION
```

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
