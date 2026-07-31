#!/usr/bin/env bash
# Run every task against your CURRENT live config and record results under an
# arm label. This script never modifies your config — you switch configs
# between arms yourself (bin/restore.sh --yes for baseline, re-apply your trim
# for the trimmed arm), then run each arm.
#
# Usage: bin/run-eval.sh <arm-label> [task ...]
#   EVAL_N=3 bin/run-eval.sh trimmed          # 3 runs of every task
#   bin/run-eval.sh baseline caching          # 1 run of one task
#
# Each task directory needs: prompt.txt (the task), check.sh (exit 0 = pass),
# and optionally fixture/ (files copied into the working dir).
set -u
EVAL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARM="${1:?arm label required, e.g. baseline or trimmed}"
shift
TASKS=("$@")
if [ ${#TASKS[@]} -eq 0 ]; then TASKS=($(ls "$EVAL_DIR/tasks")); fi
N="${EVAL_N:-1}"

CSV="$EVAL_DIR/results.csv"
[ -f "$CSV" ] || echo "date,arm,task,run,ok,cost_usd,turns,dur_s" > "$CSV"

for task in "${TASKS[@]}"; do
  T="$EVAL_DIR/tasks/$task"
  [ -f "$T/prompt.txt" ] || { echo "skip $task (no prompt.txt)"; continue; }
  for i in $(seq 1 "$N"); do
    work="$(mktemp -d "${TMPDIR:-/tmp}/cce-$task-XXXX")"
    [ -d "$T/fixture" ] && cp -R "$T/fixture/." "$work/"
    echo ">> $ARM / $task / run $i"
    out="$work/.result.json"
    (cd "$work" && claude -p --output-format json \
      --permission-mode acceptEdits < "$T/prompt.txt" > "$out" 2>"$work/.stderr")
    cost=$(jq -r '.total_cost_usd // 0' "$out" 2>/dev/null)
    turns=$(jq -r '.num_turns // 0' "$out" 2>/dev/null)
    dur=$(jq -r '(.duration_ms // 0)/1000 | floor' "$out" 2>/dev/null)
    jq -r '.result // ""' "$out" > "$work/.result.txt" 2>/dev/null
    mkdir -p "$EVAL_DIR/runs"
    cp "$work/.result.txt" "$EVAL_DIR/runs/$ARM-$task-$i.txt" 2>/dev/null

    # API errors are recorded as 'error', never as behavioral failures.
    if [ "$(jq -r '.is_error // false' "$out" 2>/dev/null)" = "true" ]; then
      echo "$(date +%F),$ARM,$task,$i,error,$cost,$turns,$dur" >> "$CSV"
      echo "   ERROR (api): $(jq -r '.result' "$out" | head -c 80)"
      continue
    fi

    ok=manual
    if [ -x "$T/check.sh" ]; then
      if (cd "$work" && "$T/check.sh" "$work/.result.txt"); then ok=pass; else ok=fail; fi
    fi
    echo "$(date +%F),$ARM,$task,$i,$ok,$cost,$turns,$dur" >> "$CSV"
    echo "   $ok cost=\$$cost turns=$turns ${dur}s (workdir kept: $work)"
  done
done
echo "results: $CSV"
echo "Before trusting a fail: read the kept workdir. Audit the judge before the defendant."
