#!/usr/bin/env bash
# Restore your Claude Code config from the snapshot taken by bin/snapshot.sh.
# DRY-RUN BY DEFAULT: shows exactly what would be overwritten. Nothing changes
# until you pass --yes.
# Usage: bin/restore.sh [--yes]
set -euo pipefail

SNAP="${CCE_SNAPSHOT_DIR:-$HOME/.claude-config-evals-snapshot}"
APPLY=false
[ "${1:-}" = "--yes" ] && APPLY=true

if [ ! -d "$SNAP/claude" ]; then
  echo "No snapshot found at $SNAP — run bin/snapshot.sh first." >&2
  exit 1
fi

restore() { # restore() snap_path live_path
  if [ ! -e "$1" ]; then return; fi
  if $APPLY; then
    rm -rf "$2"
    cp -R "$1" "$2"
    echo "restored  $2"
  else
    echo "would restore  $2"
  fi
}

restore "$SNAP/claude/CLAUDE.md"     "$HOME/.claude/CLAUDE.md"
restore "$SNAP/claude/settings.json" "$HOME/.claude/settings.json"
restore "$SNAP/claude/skills"        "$HOME/.claude/skills"
restore "$SNAP/claude/agents"        "$HOME/.claude/agents"

if $APPLY; then
  echo "Done. Sessions started from now on use the restored config."
else
  echo ""
  echo "Dry run only — nothing was changed. Re-run with --yes to apply."
  echo "Single files can also be recovered from git history: cd $SNAP && git log"
fi
