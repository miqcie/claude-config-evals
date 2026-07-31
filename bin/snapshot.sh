#!/usr/bin/env bash
# Snapshot your Claude Code config into a local git repo BEFORE trimming
# anything. This is the unwind path: every later restore comes from here.
# Usage: bin/snapshot.sh [label]
#
# Covers all of ~/.claude except session data, caches, and credentials
# (see EXCLUDES). Credentials are never copied. The snapshot may still contain
# secrets from settings env blocks — it stays chmod 700; never push it to a
# remote.
set -euo pipefail

SNAP="${CCE_SNAPSHOT_DIR:-$HOME/.claude-config-evals-snapshot}"
LABEL="${1:-snapshot}"

command -v rsync >/dev/null || { echo "need rsync on PATH" >&2; exit 1; }

mkdir -p "$SNAP"
chmod 700 "$SNAP"
cd "$SNAP"
git init -q 2>/dev/null || true

# Session data / caches / secrets that are not config and must not be copied.
EXCLUDES=(
  --exclude '.credentials.json'
  --exclude 'projects/'
  --exclude 'todos/'
  --exclude 'statsig/'
  --exclude 'shell-snapshots/'
  --exclude 'plugins/cache/'
  --exclude 'history.jsonl'
  --exclude 'usage-log/'
  --exclude '*.db'
)

# --delete makes each snapshot represent one point in time: files you removed
# from the live config disappear from the snapshot tree too (history stays in git).
rsync -a --delete "${EXCLUDES[@]}" "$HOME/.claude/" "$SNAP/claude/"

# Embedded git repos inside skills/ would confuse the snapshot repo — inline them.
find "$SNAP/claude" -name .git -type d -exec rm -rf {} + 2>/dev/null || true

git add -A
git commit -qm "$LABEL: $(date +%F)" || echo "No changes since last snapshot."
echo "Snapshot committed in $SNAP"
echo "Unwind at any time with: bin/restore.sh (dry run) then bin/restore.sh --yes"
