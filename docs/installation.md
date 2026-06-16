# Installation

## Requirements

- Linux
- Bash or Zsh
- Git for cloning the repository

UniShell itself is pure Bash and does not require a package manager dependency. Optional fuzzy navigation uses `fzf` and optional smart jumping uses `zoxide`.

## Install

```bash
git clone https://github.com/dineTH2003-dev/uni-terminal.git
cd uni-terminal
./install.sh
```

The installer tries to install the optional `fzf` and `zoxide` tools automatically. To skip optional tool installation:

```bash
./install.sh --no-optional-tools
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
unishell tools status
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
5. Automatically tries to install optional `fzf` and `zoxide` tools when missing.
6. Sources `~/.unishell/core/loader.sh`.
7. Creates the default `~/workspace` folders.

## Optional Tools

Rerun optional tool setup later with:

```bash
unishell tools install
```

Check them with:

```bash
unishell tools status
```

UniShell loads `fzf` shell integration and `zoxide init` automatically when those tools are installed and the shell is interactive. If they are missing, UniShell shows warnings in `doctor` but the rest of the toolkit keeps working.

## Reinstall

Run `./install.sh` again. If `~/.unishell` exists, the installer asks before replacing it and backs up the existing installation first.

## Uninstall

```bash
~/.unishell/uninstall.sh
```

The uninstaller removes UniShell files and shell config lines. It never deletes `~/workspace`.
