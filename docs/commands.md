# Commands

UniShell provides 6 developer intelligence commands. `predict` loads at shell startup so failed-command interception is active immediately; the other commands are lazy-loaded on first use.

## `showme` — GUI Transparency Engine

Shows the real Linux commands behind every desktop GUI action in real time.

```bash
showme              # Open a new terminal window with live monitoring
showme --inline     # Stream to the current terminal
showme stop         # Stop all monitoring sessions
showme status       # Check if showme is running
showme help         # Show usage
```

### Monitoring Layers

| Layer | Tool | What It Catches |
| --- | --- | --- |
| Filesystem | `inotifywait` | File create, delete, rename, move, permission changes |
| D-Bus | `dbus-monitor` | Network, USB, Bluetooth, display, volume changes |
| Journal | `journalctl` | Package installs/removes, service starts/stops |

### Requirements

- `inotify-tools` (Linux) or `fswatch` (macOS)
- `dbus-monitor` (pre-installed on GNOME/KDE)
- `journalctl` (pre-installed on systemd distros)

---

## `predict` — Real-time Git Predictive Auto-Suggestions

Analyzes your repository state in real-time and auto-completes Git commands directly into your terminal.

```bash
predict on          # Enable Ctrl+G auto-suggestions for this session
predict off         # Disable Ctrl+G auto-suggestions
```

### How It Works

1. Binds to `Ctrl+G` using `readline` (Bash) or `zle` (Zsh)
2. When you press `Ctrl+G`, it analyzes the `.git` directory and remote state
3. Checks for:
   - Merge/rebase conflicts (`git merge --continue`)
   - Missing upstreams (`git push --set-upstream origin ...`)
   - Detached HEAD (`git checkout -b new-branch-name`)
   - Unstaged files (`git add .` or `git commit -m`)
4. Replaces the current command line buffer with the suggested command

---

## `ghostsave` — Invisible Shadow Commits

Creates hidden Git snapshots automatically, outside of your normal git history.

```bash
ghostsave enable    # Start auto-saving (15-minute intervals)
ghostsave disable   # Stop auto-saving
ghostsave status    # Check if enabled and last save time
ghostsave restore   # Browse and restore a hidden snapshot
ghostsave squash "message"  # Collapse all ghosts into one real commit
ghostsave purge     # Delete all ghost history for current branch
```

### How It Works

- Uses a temp Git index (not your real one) to create commit trees
- Stores commits under `refs/ghosts/<branch>` — invisible to `git log` and `git push`
- 15-minute throttle prevents excessive I/O
- `ghostsave restore` stashes current work safely before restoring

---

## `context` — Per-Project Command Memory

Logs every command per project directory with automatic recall on entry.

```bash
context replay         # Re-run saved setup commands interactively
context mark-setup N   # Tag the last N commands as project setup
context search TERM    # Search command history for the current project
context projects       # List all projects with saved history
```

### How It Works

- Appends every command with timestamp to `~/.unishell/context/<project>.log`
- On first `cd` into a project each session, shows "last active" date and recent commands
- Secrets matching `password=`, `token=`, `secret=`, `key=` are automatically redacted
- Setup commands can be replayed interactively with `y/n/q` controls

---

## `drift` — Environment Drift Detector

Detects when tool versions or dependencies change between project sessions.

```bash
drift snapshot      # Save current environment state
drift diff          # Show what changed since last snapshot
drift reset         # Update the baseline to current state
drift list          # List all projects with saved snapshots
```

### What It Tracks

- Tool versions (node, python, go, rust, java, etc.)
- Dependency file checksums (package.json, requirements.txt, Cargo.toml, etc.)
- `.env` key names (not values — never stores secrets)
- PATH fingerprint

### How It Works

- Saves snapshots to `~/.unishell/drifts/<project>.snap`
- PROMPT_COMMAND hook fires only on directory change (one string comparison when idle)
- Checksums computed in pure `awk` — no external hash tool dependency

---

## `broadcast` — LAN Terminal Streaming

Streams terminal output to any browser on your local network.

```bash
broadcast start     # Start streaming (prints URL to share)
broadcast stop      # Stop the stream and clean up
```

### How It Works

- Uses `script` to capture terminal output to a RAM-backed FIFO
- A pure-Bash HTTP server (using `nc`) serves an HTML page with Server-Sent Events
- Inline `awk` converts ANSI terminal colors to HTML in real time
- Strictly read-only — the HTTP server never writes to your TTY

### Requirements

- `script` (part of `util-linux`, pre-installed)
- `nc` (netcat, pre-installed on most distros)
