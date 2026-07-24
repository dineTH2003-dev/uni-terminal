# Installation

## Requirements

- Bash 4.0+ or Zsh 5.0+
- Git (for ghostsave and installation)
- Standard Linux tools: `awk`, `grep`, `sed`, `nc` (netcat)

### Optional (for specific features)

| Tool | Feature | Install |
| --- | --- | --- |
| `inotify-tools` | showme filesystem layer | `sudo apt install inotify-tools` |
| `fswatch` | showme on macOS | `brew install fswatch` |
| `dbus-tools` | showme D-Bus layer | Pre-installed on GNOME/KDE |

## Install

```bash
git clone https://github.com/dineTH2003-dev/uni-terminal.git
cd uni-terminal
./install.sh
```

For Bash:

```bash
source ~/.bashrc
```

For Zsh:

```bash
source ~/.zshrc
```

## Verify

```bash
unishell help
unishell version
```

## Update

```bash
cd uni-terminal
git pull
./install.sh
source ~/.bashrc
```

## Cross-Platform Notes

### WSL2 (Windows)

Full support. Install WSL2 first:

```powershell
# In PowerShell as Administrator
wsl --install
```

Then install UniShell inside WSL as normal.

Note: `showme` requires WSLg for GUI monitoring. Use `showme --inline` for filesystem-only monitoring without a GUI.

### macOS

Near-full support. Install `fswatch` for the `showme` feature:

```bash
brew install fswatch
```

### Git Bash (Windows)

Core features work: `autopsy`, `ghostsave`, `context`, `drift`.

Limited: `showme` and `broadcast` require Linux-specific tools.

For full support, use WSL2 instead of Git Bash.

## Uninstall

```bash
~/.unishell/uninstall.sh
```

This removes `~/.unishell` and the UniShell block from your shell config. Your project data is never touched.
