# UniShell

UniShell is a pure Bash shell toolkit for students, developers, and DevOps beginners. It is not a terminal emulator. It installs into `~/.unishell`, adds one source line to your shell config, and gives you a practical set of workspace, project, Git, and system commands.

## Features

- Workspace bootstrap with `unishell init`
- Navigation aliases for common study and project directories
- Assignment generator with a ready-to-edit checklist
- Project generator for basic, Python, and Node.js projects
- Beginner-friendly Git helpers
- System helper commands for ports, disk, memory, IPs, services, and Docker cleanup
- `unishell doctor` environment report
- Optional `fzf` and `zoxide` integration for fuzzy navigation and smart folder jumping
- `unishell off` for temporarily returning to a normal shell session
- Clean uninstaller that leaves `~/workspace` untouched

## Install

```bash
git clone https://github.com/dineTH2003-dev/uni-terminal.git
cd uni-terminal
./install.sh
source ~/.bashrc
```

By default, the installer also tries to install the optional `fzf` and `zoxide` tools automatically. To skip that step, use:

```bash
./install.sh --no-optional-tools
```

You can rerun optional tool setup later through UniShell:

```bash
unishell tools install
```

If you use Zsh, reload `~/.zshrc` instead:

```bash
source ~/.zshrc
```

## Update

If you already installed UniShell and then pull new changes from GitHub, run the installer again so the updated files are copied into `~/.unishell`:

```bash
git pull
./install.sh
source ~/.zshrc
```

For Bash, use `source ~/.bashrc`.

## Quick Start

```bash
unishell doctor
unishell tools status
unishell init
ws
mkassign dbms-lab-01
mkproject demo-api --python
openproj
editfile
gstatus
ports
diskcheck
```

## Commands

| Command | Description |
| --- | --- |
| `unishell init` | Create the standard `~/workspace` structure |
| `unishell doctor` | Check shell, dependencies, install path, and workspace |
| `unishell tools status` | Check optional `fzf` and `zoxide` tools |
| `unishell tools install` | Install missing optional `fzf` and `zoxide` tools |
| `unishell off` | Disable UniShell in the current shell session |
| `unishell help` | Show command help |
| `unishell version` | Print the current version |
| `mkassign NAME` | Create a university assignment folder |
| `mkproject NAME --basic` | Create a basic project |
| `mkproject NAME --python` | Create a Python project |
| `mkproject NAME --node` | Create a Node.js project |
| `openproj [DIR]` | Fuzzy select and cd into a workspace/project folder |
| `cdf` | Fuzzy cd into a folder below the current directory |
| `editfile` | Fuzzy select and open a file in `$EDITOR` |
| `j NAME` / `ji` | Smart zoxide jump commands when zoxide is installed |
| `jump NAME` | UniShell wrapper around the zoxide jump command |
| `gstatus` | Show concise Git status |
| `gsave "message"` | Add all changes and commit |
| `gpush` | Show remote URL, then push |
| `glog` | Show the last 20 commits as a graph |
| `gnew branch-name` | Create and switch to a new branch |
| `gundo` | Soft reset the last commit after confirmation |
| `sysinfo` | Show OS, CPU, RAM, and uptime |
| `ports` | Show listening TCP/UDP ports |
| `myip` | Show local IP and public IP when reachable |
| `diskcheck` | Show disk usage |
| `memcheck` | Show memory usage |
| `service-check NAME` | Show `systemctl status` for a service |
| `docker-clean` | Remove stopped containers and dangling images |

## Aliases

| Alias | Destination |
| --- | --- |
| `ws` | `~/workspace` |
| `uni` | `~/workspace/university` |
| `proj` | `~/workspace/projects` |
| `devops` | `~/workspace/devops` |
| `learn` | `~/workspace/learning` |
| `scripts` | `~/workspace/scripts` |

## Optional Tools

`fzf` and `zoxide` are optional engines. UniShell detects them at startup, loads their Bash/Zsh integrations when available, and keeps working when they are missing.

```bash
unishell tools status
unishell tools install
```

Set these before loading UniShell if you want to disable an integration:

```bash
export UNISHELL_ENABLE_FZF=0
export UNISHELL_ENABLE_ZOXIDE=0
```

## Temporarily Disable UniShell

UniShell runs inside your existing Bash or Zsh session. To stop using UniShell commands and aliases in the current terminal tab:

```bash
unishell off
```

or:

```bash
uniexit
```

This does not uninstall UniShell. To load it again in the same Zsh tab:

```bash
source ~/.zshrc
```

## Uninstall

```bash
~/.unishell/uninstall.sh
```

The uninstaller removes `~/.unishell` and the UniShell block from `~/.bashrc` and `~/.zshrc`. It does not delete `~/workspace`.

## Documentation

- [Installation](docs/installation.md)
- [Commands](docs/commands.md)
- [Templates](docs/templates.md)
- [Roadmap](docs/roadmap.md)

## License

MIT
