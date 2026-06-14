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
- Clean uninstaller that leaves `~/workspace` untouched

## Install

```bash
git clone https://github.com/dineTH2003-dev/uni-terminal.git
cd uni-terminal
./install.sh
source ~/.bashrc
```

If you use Zsh, reload `~/.zshrc` instead:

```bash
source ~/.zshrc
```

## Quick Start

```bash
unishell doctor
unishell init
ws
mkassign dbms-lab-01
mkproject demo-api --python
gstatus
ports
diskcheck
```

## Commands

| Command | Description |
| --- | --- |
| `unishell init` | Create the standard `~/workspace` structure |
| `unishell doctor` | Check shell, dependencies, install path, and workspace |
| `unishell help` | Show command help |
| `unishell version` | Print the current version |
| `mkassign NAME` | Create a university assignment folder |
| `mkproject NAME --basic` | Create a basic project |
| `mkproject NAME --python` | Create a Python project |
| `mkproject NAME --node` | Create a Node.js project |
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
