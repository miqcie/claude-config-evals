#!/usr/bin/env bash
# Restore your Claude Code config from the snapshot taken by bin/snapshot.sh.
# DRY-RUN BY DEFAULT: shows exactly what would change. Nothing is modified
# until you pass --yes.
# Usage: bin/restore.sh [--yes]
#
# Restores exactly the set the snapshot covers, including deleting config
# files you created after the snapshot (so restore = the snapshot state, not a
# merge). Session data, caches, and credentials were never snapshotted and are
# never touched (same exclude list as snapshot.sh).
set -euo pipefail

SNAP="${CCE_SNAPSHOT_DIR:-$HOME/.claude-config-evals-snapshot}"
APPLY=false
[ "${1:-}" = "--yes" ] && APPLY=true

command -v rsync >/dev/null || { echo "need rsync on PATH" >&2; exit 1; }

if [ ! -d "$SNAP/claude" ]; then
  echo "No snapshot found at $SNAP — run bin/snapshot.sh first." >&2
  exit 1
fi

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

FLAGS=(-a --delete "${EXCLUDES[@]}")
if $APPLY; then
  rsync "${FLAGS[@]}" --itemize-changes "$SNAP/claude/" "$HOME/.claude/"
  echo "Done. Sessions started from now on use the restored config."
else
  echo "Dry run — this is what --yes would change in ~/.claude:"
  rsync "${FLAGS[@]}" --dry-run --itemize-changes "$SNAP/claude/" "$HOME/.claude/"
  echo ""
  echo "Nothing was changed. Re-run with --yes to apply."
  echo "Single files can also be recovered from git history: cd $SNAP && git log"
fi
