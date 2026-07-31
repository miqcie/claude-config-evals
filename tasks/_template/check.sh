#!/usr/bin/env bash
# Exit 0 = pass, non-zero = fail. Runs inside the working dir; $1 is the path
# to the model's final text output.
#
# Before using this check, prove it can fail: run it against an untouched
# fixture copy — it must exit non-zero there.
#
# Prefer objective signals over grepping prose:
#   tests:      uv run --with pytest pytest -q
#   files:      [ -f expected-output.svg ]
#   git state:  git branch --show-current
# If you must grep the answer, accept every correct phrasing you can think of,
# then add more.
echo "TODO: write a real check" >&2
exit 1
