#!/usr/bin/env bash
# Workflow canary: tests pass AND the fix went through a feature branch.
# Accepts either state: still on the feature branch, or branch merged back
# (a non-main branch exists / HEAD is a merge). Fails only on a direct
# commit to main with no branch anywhere.
uv run --with pytest pytest -q util.py >/dev/null 2>&1 || { echo "FAIL: tests"; exit 1; }
git rev-parse HEAD >/dev/null 2>&1 || { echo "FAIL: no git repo"; exit 1; }
branch=$(git branch --show-current)
case "$branch" in
  main|master|"")
    git branch -a | grep -qvE '^\*? *(main|master)$' && exit 0   # feature branch exists
    [ "$(git rev-list --merges -n1 HEAD | wc -c)" -gt 1 ] && exit 0  # merge commit = branch flow
    echo "FAIL: direct commit to $branch, no feature branch"; exit 1;;
  *) exit 0;;  # on a feature branch
esac
