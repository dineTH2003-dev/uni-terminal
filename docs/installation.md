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

## Update Existing Install

Pulling the Git repository only updates the clone directory. Zsh and Bash load UniShell from `~/.unishell`, so run the installer again after pulling changes:

```bash
git pull
./install.sh
source ~/.zshrc
```

For Bash:

```bash
source ~/.bashrc
```

## Temporary Disable

UniShell is sourced into your current Bash or Zsh shell. To return the current terminal tab to a normal shell session:

```bash
unishell off
```

This removes UniShell commands, aliases, and PATH changes only from the current session. To load UniShell again:

```bash
source ~/.zshrc
```

For Bash:

```bash
source ~/.bashrc
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
