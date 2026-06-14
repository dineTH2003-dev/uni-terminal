# Contributing to UniShell

Thanks for helping improve UniShell.

## Local Setup

```bash
git clone https://github.com/dineTH2003-dev/uni-terminal.git
cd uni-terminal
bash tests/test-install.sh
```

## Adding a Command

1. Add the function to the most relevant file in `commands/`.
2. Keep command names short and memorable.
3. Validate required arguments before doing work.
4. Use the shared output helpers from `core/config.sh`: `ok`, `warn`, `info`, and `err`.
5. Update `README.md` and `docs/commands.md`.
6. Add smoke coverage to `tests/test-install.sh` when practical.

## Rules

- Keep UniShell pure Bash.
- Do not add required runtime dependencies.
- Do not delete or overwrite user data without confirmation.
- Prefer clear output over clever output.
- Make commands safe to run more than once when possible.
