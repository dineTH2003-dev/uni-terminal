# UniShell

**A developer intelligence toolkit that runs inside your terminal.**

UniShell is not another shell theme or prompt. It is a set of 6 deeply engineered, research-backed features that act as invisible safety nets and learning tools for developers — from students to professionals.

It installs into `~/.unishell`, adds one line to your shell config, and gives you capabilities that no other terminal tool provides.

## The 6 Features

### 🔍 `showme` — GUI Transparency Engine
Opens a new terminal window that shows the **real Linux commands** happening behind every GUI action you perform on your desktop.

Click "New Folder" in Files → the terminal shows `mkdir "/home/you/Desktop/NewFolder"`.
Connect to WiFi → the terminal shows `nmcli device wifi connect "Network"`.
Install an app → the terminal shows `sudo apt-get install vlc`.

**For students:** Learn Linux commands naturally by using your desktop normally.
**For professionals:** Instantly capture the exact CLI equivalent of any GUI action for automation scripts.

```bash
showme              # Opens a new terminal window with live command stream
showme --inline     # Stream to the current terminal instead
showme stop         # Stop monitoring
```

### 🔮 `predict` — Real-time Git Predictive Auto-Suggestions
Forget waiting for a Git command to fail. Predict analyzes your repository state (merge conflicts, detached HEAD, missing upstreams, etc.) **in real-time** and auto-completes the perfect command directly into your terminal.

```
$ git push <Press Ctrl+G>
$ git push --set-upstream origin feature-x
```

```bash
predict on          # Enable Ctrl+G auto-suggestions
predict off         # Disable Ctrl+G auto-suggestions
```

### 👻 `ghostsave` — Invisible Shadow Commits
Automatically creates hidden Git snapshots every 15 minutes — outside of your normal git log and remote repos. A time machine that requires zero discipline.

```bash
ghostsave enable    # Start auto-saving
ghostsave interval 300  # Change interval to 5 min (default: 15 min)
ghostsave restore   # Browse and restore a hidden snapshot
ghostsave squash "message"  # Collapse all ghosts into one clean commit
ghostsave status    # Check if enabled
```

### 🧠 `context` — Per-Project Command Memory
Automatically logs every command per project directory. When you `cd` into a project you haven't touched in months, it tells you exactly what you were doing last time.

```
$ cd ~/projects/billing-service
  Last active: 47 days ago
  Last commands:
    1. docker-compose up -d
    2. npm run migrate
    3. npm run dev
```

```bash
context replay      # Re-run saved setup commands interactively
context mark-setup 5  # Tag the last 5 commands as "setup"
context search "docker"  # Search project command history
```

### 🔀 `drift` — Environment Drift Detector
Snapshots your tool versions, dependency hashes, and PATH state. Warns you instantly when the environment changes so you never waste hours debugging phantom issues.

```
$ cd ~/projects/web-app
⚠ DRIFT DETECTED:
  node: 18.17.0 → 20.11.0
  package.json checksum changed
  Run 'npm install' to update dependencies.
```

```bash
drift snapshot      # Save current environment state
drift diff          # Show what changed since last snapshot
drift reset         # Update the baseline
drift list          # List all tracked projects
```

### 📡 `broadcast` — LAN Terminal Streaming
Stream your terminal output to any browser on your local network. Read-only, no accounts, no cloud.

```bash
broadcast start     # Start streaming at http://your-ip:7681
broadcast stop      # Stop the stream
```

**For students:** Share your terminal with a TA for debugging without screen sharing.
**For teams:** Let teammates watch a deployment in real time from their browser.

## Install

```bash
git clone https://github.com/dineTH2003-dev/uni-terminal.git
cd uni-terminal
./install.sh
source ~/.bashrc    # or source ~/.zshrc for Zsh
```

## Update

```bash
cd uni-terminal
git pull
./install.sh
source ~/.bashrc
```

## Cross-Platform Support

| Platform | Support Level |
| --- | --- |
| **Linux** | ✅ Full support |
| **WSL2** (Windows) | ✅ Full support |
| **macOS** | ⚠️ Near-full (needs `brew install fswatch` for showme) |
| **Git Bash** (Windows) | ⚠️ Core features (predict, ghostsave, context, drift) |

## Architecture

UniShell keeps startup small with a hybrid loading model. `predict` is loaded at boot because real-time interception must be active before your first command; the other command modules are registered as lightweight lazy stubs and load on first use. This means:

- **Low boot overhead** — UniShell keeps startup work minimal
- **Zero daemons** — All background monitoring uses native shell hooks (`PROMPT_COMMAND` / `precmd`)
- **Zero internet** — Everything runs offline, all data stays in `~/.unishell/`
- **Zero dependencies** — Uses standard POSIX tools (`awk`, `grep`, `sed`, `git`, `nc`)

## Temporarily Disable

```bash
unishell off        # Disable in the current session
uniexit             # Same thing
source ~/.bashrc    # Re-enable
```

## Uninstall

```bash
~/.unishell/uninstall.sh
```

## License

MIT
