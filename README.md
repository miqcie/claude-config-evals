# claude-config-evals

A/B eval harness for trimming your Claude Code config with evidence instead of
vibes.

Anthropic [removed over 80% of Claude Code's own system prompt](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models)
for their newest models and measured no performance loss. The same logic
applies to your accumulated CLAUDE.md rules, skills, and plugin personas — but
deleting config is easy, and knowing you didn't break your setup is the hard
part. This harness measures it: run the same fixed tasks against your old and
trimmed configs, compare pass rates and cost, and get a verdict.

Born from [this experiment](https://humaine.studio) trimming a ~12K-token
always-on config to ~6K with no behavior loss and 10–15% lower cost per run.

## How it works

Each task is a **canary**: a small headless job with an objective pass/fail
check, mapped to one specific rule you cut. If the rule was load-bearing, its
canary fails and points at exactly what to restore. Three example tasks ship in
`tasks/`; the interesting ones are the ones your own Claude writes for *your*
config (see Personalizing below).

## Quickstart

Requirements: Claude Code CLI (logged in), `jq`, `git`, Python 3. Runs cost
real API money (roughly $0.50–1.50 per task run).

```bash
git clone https://github.com/miqcie/claude-config-evals
cd claude-config-evals

# 1. SNAPSHOT FIRST — this is your undo button. Do this before trimming anything.
bin/snapshot.sh

# 2. Baseline the current config
EVAL_N=3 bin/run-eval.sh baseline

# 3. Trim your config (or have Claude do it — see Personalizing)

# 4. Run the trimmed arm
EVAL_N=3 bin/run-eval.sh trimmed

# 5. Render the verdict
python3 dashboard/make-dashboard.py
open dashboard.html
```

To unwind everything: `bin/restore.sh` shows what would change (dry run by
default); `bin/restore.sh --yes` puts your snapshot back. Single files are
recoverable from the snapshot's git history.

## Personalizing (the whole point)

Open Claude Code in this repo and say:

> Audit my Claude Code config per this repo's CLAUDE.md: inventory what's
> injected at session start, sort it into hard rules / gotchas / generic
> behavior, propose a trim, and write one canary task per cut.

The repo's `CLAUDE.md` teaches your agent the workflow: snapshot before
touching anything, generate tasks in the `tasks/_template/` shape, and verify
each check can actually fail before trusting it. Your canaries end up specific
to your setup — that's what makes the verdict meaningful.

## Reading failures honestly

**When an eval fails, audit the judge before the defendant.** In the original
experiment, 4 of 7 flagged failures were check-script bugs, not model
regressions (a correct branch-and-merge workflow scored as fail; a correct
"expressly ineligible" answer missed by a grep that only knew "not eligible").
Every run's working directory is kept and every transcript lands in `runs/` —
read them before restoring rules.

Known quirks, learned the hard way:

- **Headless runs sometimes commit to `main`** regardless of config prose,
  under old and trimmed configs alike. It's a headless-mode property; enforce
  branch discipline with a hook or the automation's own prompt, not more rules.
- **API-error runs are recorded as `error`**, excluded from pass rates. A $0
  instant "failure" is an auth or API problem, not a behavior signal — and a
  check can false-*pass* on an untouched fixture, so checks must fail on
  fixtures by construction.
- **`CLAUDE_CONFIG_DIR` isolation doesn't work on macOS** (login lives in the
  Keychain), which is why the harness measures the live config and keeps the
  swap explicit and reversible instead of pretending to sandbox.

## Decision rule

Keep the trim only if the trimmed arm's pass rate and every individual canary
are non-inferior to baseline. One canary regressing means restoring that one
rule from the snapshot's git history — not reverting the whole trim.

## Contributing

New general-purpose canary tasks welcome (a task is general-purpose if it's
useful to someone with a completely different config). One task per PR:
`prompt.txt` + `check.sh` + optional `fixture/`, self-contained and offline,
and the check must fail on the untouched fixture. Personal/domain-specific
tasks belong in your fork — that's what the template is for.

MIT license.
