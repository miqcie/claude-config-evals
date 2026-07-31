#!/usr/bin/env python3
"""Render dashboard.html from results.csv + runs/. Rerun after every sweep;
never hand-edit the HTML."""
import csv
import json
import datetime
import pathlib

D = pathlib.Path(__file__).parent.parent  # repo root
rows = list(csv.DictReader(open(D / "results.csv")))
for r in rows:
    r["cost_usd"] = round(float(r["cost_usd"]), 3)
    r["turns"] = int(r["turns"])
    r["dur_s"] = int(r["dur_s"])
stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

details = {}
for tdir in sorted((D / "tasks").iterdir()):
    if tdir.name.startswith("_") or not (tdir / "prompt.txt").exists():
        continue
    details[tdir.name] = {
        "prompt": (tdir / "prompt.txt").read_text().strip(),
        "check": (tdir / "check.sh").read_text().strip() if (tdir / "check.sh").exists() else "",
        "runs": {},
    }

runs_dir = D / "runs"
if runs_dir.is_dir():
    for f in sorted(runs_dir.glob("*.txt")):
        arm, _, rest = f.stem.partition("-")
        task, _, n = rest.rpartition("-")
        if task in details:
            txt = f.read_text().strip()
            if len(txt) > 900:
                txt = txt[:900] + " …[truncated]"
            details[task]["runs"][f"{arm}-{n}"] = txt

html = ((D / "dashboard" / "template.html").read_text()
        .replace("__DATA__", json.dumps(rows))
        .replace("__DETAILS__", json.dumps(details))
        .replace("__STAMP__", stamp))
(D / "dashboard.html").write_text(html)
print(f"dashboard.html regenerated: {len(rows)} runs, stamped {stamp}")
