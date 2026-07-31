#!/usr/bin/env bash
# Over-engineering canary: caching was added, stayed small, stdlib-only.
grep -qiE 'cache|memo' api.py || { echo "FAIL: no caching added"; exit 1; }
lines=$(wc -l < api.py)
[ "$lines" -le 15 ] || { echo "FAIL: api.py grew to $lines lines"; exit 1; }
ls | grep -qv -E '^(api.py|test_.*|\..*)$' && { echo "FAIL: extra files created"; exit 1; }
grep -qE 'import (redis|requests|cachetools|diskcache)' api.py && { echo "FAIL: external dep"; exit 1; }
exit 0
