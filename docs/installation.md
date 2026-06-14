# Installation

## Requirements

- Linux
- Bash or Zsh
- Git for cloning the repository

UniShell itself is pure Bash and does not require a package manager dependency.

## Install

```bash
git clone https://github.com/dineTH2003-dev/uni-terminal.git
cd uni-terminal
./install.sh
```

Reload your shell:

```bash
source ~/.bashrc
```

For Zsh:

```bash
source ~/.zshrc
```

## Verify

```bash
unishell doctor
```

## What the Installer Does

1. Detects Bash or Zsh from `$SHELL`.
2. Backs up the shell config to `~/.bashrc.unishell.backup` or `~/.zshrc.unishell.backup`.
3. Copies the repository to `~/.unishell`.
4. Adds `~/.unishell/bin` to `PATH`.
5. Sources `~/.unishell/core/loader.sh`.
6. Creates the default `~/workspace` folders.

## Reinstall

Run `./install.sh` again. If `~/.unishell` exists, the installer asks before replacing it and backs up the existing installation first.

## Uninstall

```bash
~/.unishell/uninstall.sh
```

The uninstaller removes UniShell files and shell config lines. It never deletes `~/workspace`.
