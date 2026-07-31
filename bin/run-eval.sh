#!/usr/bin/env bash
# Run tasks against your CURRENT live config and record results under an arm
# label. This script never modifies your config — you switch configs between
# arms yourself (bin/restore.sh --yes for baseline, re-apply your trim for the
# trimmed arm), then run each arm.
#
# Usage: bin/run-eval.sh <arm-label> [task ...]
#   EVAL_N=3 bin/run-eval.sh baseline         # 3 runs of every task
#   bin/run-eval.sh trimmed caching           # 1 run of one task
#   EVAL_MODEL=sonnet ...                     # pin the model (default: sonnet)
#
# SECURITY: task directories are executable content. prompt.txt drives a live
# Claude session with acceptEdits and check.sh runs as your user. The first
# time a task (or a changed task) runs, you must confirm it — read it first.
set -u
EVAL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARM="${1:?arm label required, e.g. baseline or trimmed}"
shift
TASKS=("$@")
if [ ${#TASKS[@]} -eq 0 ]; then TASKS=($(ls "$EVAL_DIR/tasks" | grep -v '^_')); fi
N="${EVAL_N:-1}"
MODEL="${EVAL_MODEL:-sonnet}"

command -v claude >/dev/null || { echo "need the claude CLI on PATH" >&2; exit 1; }
command -v jq >/dev/null || { echo "need jq on PATH" >&2; exit 1; }

# Arm labels become filenames and CSV cells: letters/digits/underscore only
# (no dashes — the run-filename parser splits on the first dash).
case "$ARM" in
  *[!a-zA-Z0-9_]*) echo "arm label must be [a-zA-Z0-9_] only: '$ARM'" >&2; exit 1;;
esac

# Deterministic git identity inside task workdirs (git-flow etc.)
export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-config-evals}"
export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-evals@localhost}"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

# First-run trust gate: a task must be acknowledged before it executes, and
# re-acknowledged if its contents change. CCE_TRUST_ALL=1 skips (CI use).
TRUST="$EVAL_DIR/.trusted-tasks"
touch "$TRUST"
task_hash() { find "$EVAL_DIR/tasks/$1" -type f -print0 | sort -z | xargs -0 shasum 2>/dev/null | shasum | cut -d' ' -f1; }
ensure_trusted() {
  local t="$1" h
  h=$(task_hash "$t")
  grep -q "^$h  $t$" "$TRUST" && return 0
  [ "${CCE_TRUST_ALL:-0}" = "1" ] && { echo "$h  $t" >> "$TRUST"; return 0; }
  echo ""
  echo "Task '$t' is new or changed. Its prompt drives a live Claude session"
  echo "and its check.sh runs as your user. Contents:"
  echo "--- prompt.txt ---"; cat "$EVAL_DIR/tasks/$t/prompt.txt"
  echo "--- check.sh ---"; cat "$EVAL_DIR/tasks/$t/check.sh" 2>/dev/null || echo "(none)"
  if [ -t 0 ]; then
    printf "Run it? [y/N] "
    read -r ans
    [ "$ans" = "y" ] || return 1
  else
    echo "Non-interactive shell: review the task, then re-run with CCE_TRUST_ALL=1" >&2
    return 1
  fi
  echo "$h  $t" >> "$TRUST"
}

CSV="$EVAL_DIR/results.csv"
[ -f "$CSV" ] || echo "date,arm,task,run,ok,cost_usd,turns,dur_s,model" > "$CSV"

for task in ${TASKS[@]+"${TASKS[@]}"}; do
  case "$task" in
    *[!a-zA-Z0-9_-]*) echo "skip '$task' (task names must be [a-zA-Z0-9_-])"; continue;;
  esac
  T="$EVAL_DIR/tasks/$task"
  [ -f "$T/prompt.txt" ] || { echo "skip $task (no prompt.txt)"; continue; }
  ensure_trusted "$task" || { echo "skip $task (not trusted)"; continue; }
  for i in $(seq 1 "$N"); do
    work="$(mktemp -d "${TMPDIR:-/tmp}/cce-$task-XXXX")"
    [ -d "$T/fixture" ] && cp -R "$T/fixture/." "$work/"
    echo ">> $ARM / $task / run $i"
    out="$work/.result.json"
    (cd "$work" && claude -p --model "$MODEL" --output-format json \
      --permission-mode acceptEdits < "$T/prompt.txt" > "$out" 2>"$work/.stderr")
    cost=$(jq -r '.total_cost_usd // 0' "$out" 2>/dev/null)
    turns=$(jq -r '.num_turns // 0' "$out" 2>/dev/null)
    dur=$(jq -r '(.duration_ms // 0)/1000 | floor' "$out" 2>/dev/null)
    jq -r '.result // ""' "$out" > "$work/.result.txt" 2>/dev/null
    mkdir -p "$EVAL_DIR/runs"
    cp "$work/.result.txt" "$EVAL_DIR/runs/$ARM-$task-$i.txt" 2>/dev/null

    # API errors are recorded as 'error', never as behavioral failures.
    if [ "$(jq -r '.is_error // false' "$out" 2>/dev/null)" = "true" ]; then
      echo "$(date +%F),$ARM,$task,$i,error,${cost:-0},${turns:-0},${dur:-0},$MODEL" >> "$CSV"
      echo "   ERROR (api): $(jq -r '.result' "$out" | head -c 80)"
      continue
    fi

    ok=manual
    if [ -x "$T/check.sh" ]; then
      if (cd "$work" && "$T/check.sh" "$work/.result.txt"); then ok=pass; else ok=fail; fi
    fi
    echo "$(date +%F),$ARM,$task,$i,$ok,${cost:-0},${turns:-0},${dur:-0},$MODEL" >> "$CSV"
    echo "   $ok cost=\$$cost turns=$turns ${dur}s (workdir kept: $work)"
  done
done
echo "results: $CSV"
echo "Before trusting a fail: read the kept workdir. Audit the judge before the defendant."
