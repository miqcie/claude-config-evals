#!/usr/bin/env bash
# Workflow canary: tests pass AND the fix went through a feature branch.
# Accepts every correct shape: still on the branch, branch merged back
# (merge commit OR fast-forward with the branch kept or deleted — the reflog
# remembers the checkout either way). Fails only on a direct commit to main
# with no branch evidence anywhere.
uv run --with pytest pytest -q util.py >/dev/null 2>&1 || { echo "FAIL: tests"; exit 1; }
git rev-parse HEAD >/dev/null 2>&1 || { echo "FAIL: no git repo"; exit 1; }
branch=$(git branch --show-current)
case "$branch" in
  main|master|"")
    git branch -a | grep -qvE '^\*? *(main|master)$' && exit 0          # branch still exists
    [ "$(git rev-list --merges -n1 HEAD | wc -c)" -gt 1 ] && exit 0     # merge commit
    git reflog 2>/dev/null | grep -q 'checkout: moving from' && exit 0  # ff-merge, branch deleted
    echo "FAIL: direct commit to $branch, no feature-branch evidence"; exit 1;;
  *) exit 0;;  # on a feature branch
esac
