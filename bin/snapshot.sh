#!/usr/bin/env bash
# Snapshot your Claude Code config into a local git repo BEFORE trimming anything.
# This is the unwind path: every later restore comes from here.
# Usage: bin/snapshot.sh [label]
set -euo pipefail

SNAP="${CCE_SNAPSHOT_DIR:-$HOME/.claude-config-evals-snapshot}"
LABEL="${1:-snapshot}"

mkdir -p "$SNAP"
cd "$SNAP"
git init -q 2>/dev/null || true

copy() { # copy() src dst — skip silently if src doesn't exist
  if [ -e "$1" ]; then
    mkdir -p "$(dirname "$2")"
    cp -R "$1" "$2"
  fi
}

copy "$HOME/.claude/CLAUDE.md"            "$SNAP/claude/CLAUDE.md"
copy "$HOME/.claude/settings.json"        "$SNAP/claude/settings.json"
copy "$HOME/.claude/skills"               "$SNAP/claude/skills"
copy "$HOME/.claude/agents"               "$SNAP/claude/agents"
# Project-level config, if run from inside a project
if [ -f "./CLAUDE.md" ] && [ "$PWD" != "$SNAP" ]; then
  copy "$OLDPWD/CLAUDE.md" "$SNAP/project/CLAUDE.md" 2>/dev/null || true
fi

# Embedded git repos inside skills/ would snapshot as empty pointers — inline them.
find "$SNAP/claude/skills" -name .git -maxdepth 3 -exec rm -rf {} + 2>/dev/null || true

git add -A
git commit -qm "$LABEL: $(date +%F)" || echo "No changes since last snapshot."
echo "Snapshot committed in $SNAP"
echo "Unwind at any time with: bin/restore.sh"
