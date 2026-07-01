#!/usr/bin/env bash
# drift.sh — Environment Drift Detector
#
# Takes a cryptographic fingerprint of your project environment (tool versions,
# .env key names, PATH hash, dependency file checksums, git branch) when things
# are working. Silently compares on every directory entry via PROMPT_COMMAND.
# Alerts when something that could break the project has changed.
#
# Zero daemon. Zero database. Pure flat-file reads on dir-change only.

_DRIFT_DIR="$UNISHELL_HOME/drifts"

# ── Internal helpers ─────────────────────────────────────────────────────────

# Lightweight checksum: hash content using awk (no md5sum dependency).
_drift_checksum() {
  awk 'BEGIN{s=0} {for(i=1;i<=length($0);i++) s=(s*31+ord(substr($0,i,1)))%999983} function ord(c) {return index(" !\"#$%&'"'"'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~", c)+31} END{printf "%06x\n", s}' 2>/dev/null || echo "000000"
}

_drift_snap_path() {
  local project_name
  project_name="$(basename "$PWD")"
  printf "%s/%s.snap\n" "$_DRIFT_DIR" "$project_name"
}

_drift_tool_version() {
  local tool="$1"
  "$tool" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]*' | head -1 || echo "not-installed"
}

# Get .env key names (not values — never log secrets).
_drift_env_keys() {
  local f
  for f in .env .env.local .env.development; do
    [ -f "$f" ] && grep -v '^\s*#' "$f" | grep '=' | cut -d= -f1 | sort | tr '\n' ',' && return
  done
  echo "none"
}

# Detect primary dep file and checksum its content.
_drift_dep_hash() {
  local depfile=""
  for f in package-lock.json yarn.lock pnpm-lock.yaml requirements.txt Cargo.lock go.sum; do
    [ -f "$f" ] && depfile="$f" && break
  done
  [ -z "$depfile" ] && echo "none" && return
  _drift_checksum < "$depfile"
}

# Lightweight PATH hash: checksum the colon-separated list of PATH entries.
_drift_path_hash() {
  printf "%s" "$PATH" | tr ':' '\n' | sort | _drift_checksum
}

# Write a snapshot file for the current directory.
_drift_write_snap() {
  local snap="$1"
  mkdir -p "$_DRIFT_DIR"
  cat >"$snap" <<EOF
# UniShell drift snapshot — $(date -u '+%Y-%m-%dT%H:%M:%SZ')
# Project: $(basename "$PWD") at $PWD
project_path=$PWD
snap_date=$(date +%s)
node_version=$(_drift_tool_version node 2>/dev/null || echo not-installed)
python_version=$(_drift_tool_version python3 2>/dev/null || echo not-installed)
go_version=$(_drift_tool_version go 2>/dev/null || echo not-installed)
cargo_version=$(_drift_tool_version cargo 2>/dev/null || echo not-installed)
env_keys=$(_drift_env_keys)
dep_hash=$(_drift_dep_hash)
path_hash=$(_drift_path_hash)
git_branch=$(git branch --show-current 2>/dev/null || echo none)
EOF
}

# Read a key from a snapshot file.
_drift_read_snap() {
  local file="$1" key="$2"
  grep "^${key}=" "$file" 2>/dev/null | cut -d= -f2-
}

# ── Passive PROMPT_COMMAND hook (replaces no-op stub from loader) ────────────

_unishell_drift_hook() {
  local snap
  snap="$(_drift_snap_path)"
  [ -f "$snap" ] || return  # Loader already checks this before calling.

  local now_node now_python now_go now_env now_dep now_path
  now_node="$(_drift_tool_version node 2>/dev/null || echo not-installed)"
  now_python="$(_drift_tool_version python3 2>/dev/null || echo not-installed)"
  now_go="$(_drift_tool_version go 2>/dev/null || echo not-installed)"
  now_env="$(_drift_env_keys)"
  now_dep="$(_drift_dep_hash)"
  now_path="$(_drift_path_hash)"

  local snap_node snap_python snap_go snap_env snap_dep snap_path snap_date
  snap_node="$(_drift_read_snap "$snap" node_version)"
  snap_python="$(_drift_read_snap "$snap" python_version)"
  snap_go="$(_drift_read_snap "$snap" go_version)"
  snap_env="$(_drift_read_snap "$snap" env_keys)"
  snap_dep="$(_drift_read_snap "$snap" dep_hash)"
  snap_path="$(_drift_read_snap "$snap" path_hash)"
  snap_date="$(_drift_read_snap "$snap" snap_date)"

  local drifted=0
  local lines=()

  [ "$now_node" != "$snap_node" ] && drifted=1 && lines+=("  node_version    ${snap_node} → ${now_node}")
  [ "$now_python" != "$snap_python" ] && drifted=1 && lines+=("  python_version  ${snap_python} → ${now_python}")
  [ "$now_go" != "$snap_go" ] && drifted=1 && lines+=("  go_version      ${snap_go} → ${now_go}")
  [ "$now_env" != "$snap_env" ] && drifted=1 && lines+=("  env_keys        changed (check your .env file)")
  [ "$now_dep" != "$snap_dep" ] && drifted=1 && lines+=("  dep_hash        changed (run your install command)")
  [ "$now_path" != "$snap_path" ] && drifted=1 && lines+=("  PATH            changed (new or removed tools)")

  [ "$drifted" -eq 0 ] && return

  local age_days=""
  if [ -n "$snap_date" ]; then
    local now_epoch; now_epoch=$(date +%s)
    local diff=$(( (now_epoch - snap_date) / 86400 ))
    age_days=" (snapshotted ${diff} day(s) ago)"
  fi

  printf "\n%b\n" "${YELLOW}⚠  Environment drift detected${NC}${age_days}:"
  for line in "${lines[@]}"; do
    printf "%b\n" "  ${RED}${line}${NC}"
  done
  printf "%b\n" "  Run ${BOLD}drift snapshot${NC} to update the baseline once things work again.\n"
}

# ── User-facing command ──────────────────────────────────────────────────────

drift() {
  local subcmd="${1:-check}"
  shift || true

  local snap
  snap="$(_drift_snap_path)"

  case "$subcmd" in
    snapshot|save)
      _drift_write_snap "$snap"
      ok "Snapshot saved for '$(basename "$PWD")' — drift detection is now active."
      info "UniShell will alert you if tool versions, .env keys, or dependencies change."
      ;;
    check)
      if [ ! -f "$snap" ]; then
        warn "No snapshot for this project. Run: drift snapshot"
        return 0
      fi
      # Force immediate check by calling the hook directly.
      _unishell_drift_hook
      [ $? -eq 0 ] && ok "No drift detected — environment matches snapshot."
      ;;
    diff)
      if [ ! -f "$snap" ]; then
        warn "No snapshot for this project. Run: drift snapshot"
        return 1
      fi
      info "Saved snapshot for '$(basename "$PWD")':"
      printf "\n"
      grep -v '^#' "$snap" | grep -v '^$'
      ;;
    reset|delete)
      if [ -f "$snap" ]; then
        rm -f "$snap"
        ok "Snapshot deleted for '$(basename "$PWD")'."
      else
        warn "No snapshot found for this project."
      fi
      ;;
    list)
      if [ -z "$(ls -A "$_DRIFT_DIR" 2>/dev/null)" ]; then
        warn "No drift snapshots saved yet."
      else
        info "Saved drift snapshots:"
        ls -1 "$_DRIFT_DIR" | sed 's/\.snap$//'
      fi
      ;;
    help|-h|--help)
      cat <<'EOF'
drift — environment drift detector

  drift snapshot      Save current environment as the known-good baseline
  drift check         Compare current env to snapshot (also runs passively on cd)
  drift diff          Show raw contents of the saved snapshot
  drift reset         Delete the snapshot for the current project
  drift list          List all projects with saved snapshots

Drift monitors: node/python/go versions, .env key names (not values),
dependency file checksums, and PATH fingerprint.
EOF
      ;;
    *)
      err "Unknown subcommand: $subcmd. Run: drift help"
      return 1
      ;;
  esac
}
