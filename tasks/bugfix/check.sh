#!/usr/bin/env bash
# pass = tests green
uv run --with pytest pytest -q >/dev/null 2>&1
