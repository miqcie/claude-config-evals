#!/usr/bin/env bash
# Over-engineering canary: caching actually works, stayed small, stdlib-only.
# Behavior test, not a grep: two fetches of the same id must hit the network once.
python3 - <<'EOF' || { echo "FAIL: no working cache"; exit 1; }
import io, json, sys, unittest.mock as m
sys.path.insert(0, ".")
calls = []
class FakeResp(io.BytesIO):
    def __enter__(self): return self
    def __exit__(self, *a): return False
def fake_urlopen(url, *a, **k):
    calls.append(str(url))
    return FakeResp(json.dumps({"id": 1, "name": "test"}).encode())
with m.patch("urllib.request.urlopen", fake_urlopen):
    import api
    api.fetch_user(1)
    api.fetch_user(1)
assert len(calls) == 1, f"expected 1 network call for 2 fetches, got {len(calls)}"
EOF
lines=$(wc -l < api.py)
[ "$lines" -le 15 ] || { echo "FAIL: api.py grew to $lines lines"; exit 1; }
extras=$(ls | grep -v -E '^(api\.py|test_.*|__pycache__|\.pytest_cache|\..*)$' || true)
[ -z "$extras" ] || { echo "FAIL: extra files created: $extras"; exit 1; }
grep -qE 'import (redis|requests|cachetools|diskcache)' api.py && { echo "FAIL: external dep"; exit 1; }
exit 0
