# claude-config-evals

Harness for A/B testing a Claude Code config trim. The user wants evidence that
deleting config didn't change behavior. Your job in this repo is to personalize
the harness to THEIR setup, not to run the examples and call it done.

## The workflow you drive

1. **Snapshot first, always.** Run `bin/snapshot.sh` before any config change.
   Never trim anything until the snapshot commit exists. Restore path:
   `bin/restore.sh --yes`.
2. **Audit their setup.** Inventory everything injected at session start: user
   CLAUDE.md, project CLAUDE.md, skill descriptions, plugin session hooks, MCP
   server instructions. Estimate tokens per component. Present a table.
3. **Sort each line into 3 buckets:** a *hard rule* (real constraint — keep), a
   *gotcha* (fact the model can't discover, like "pushes here don't deploy" —
   keep), or *generic behavior* a current model does unprompted (cut).
4. **Generate canary tasks — one per meaningful cut.** This is the
   personalization step. For each rule being cut, write a task under `tasks/`
   that FAILS if the old rule was actually load-bearing. Use `tasks/_template/`
   as the shape and the shipped examples as reference. Tasks must be
   self-contained (fixture files, no network, no paths into the user's repos).
5. **Run both arms.** `bin/restore.sh --yes` → `EVAL_N=3 bin/run-eval.sh
   baseline`; re-apply the trim → `EVAL_N=3 bin/run-eval.sh trimmed`. Warn the
   user before each arm which config is live.
6. **Render and read.** `python3 dashboard/make-dashboard.py`, open
   `dashboard.html`. Verdict rule: keep the trim only if the trimmed arm's pass
   rate and every canary are non-inferior to baseline.

## Rules for writing checks (learned the hard way)

- **Audit the judge before the defendant.** When a run fails, read the kept
  working directory before concluding the model regressed. Most "failures" in
  the original experiment were check-script bugs.
- Checks must accept the diversity of correct outputs: any refusal phrasing,
  branch-then-merge as well as branch-only, synonyms of the expected answer.
- A check must not pass on an untouched fixture. Verify: run `check.sh` in a
  fresh fixture copy before using it — it must FAIL there.
- Prefer objective signals (tests pass, file exists, git state) over grepping
  prose. When you must grep, grep broadly.

## Safety rules (non-negotiable)

- Never modify `~/.claude` without a snapshot commit existing first.
- Never run `restore.sh --yes` without telling the user what it overwrites
  (`restore.sh` with no flag prints the dry-run list).
- Headless runs sometimes commit to `main` regardless of config prose — that's
  a property of headless mode, not a config regression. Don't chase it with
  more rules; note it.
