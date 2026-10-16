#!/usr/bin/env python3
"""Joins edit_cases.py output with the app's JSON log lines into a Markdown table.

Usage: python3 summarize.py <run_dir> [<run_dir> ...]
Each run_dir holds app.log (the app's stdout) and edits.log (edit_cases.py's stdout).
With several runs, times are the median and the range across runs.
"""
import json
import statistics
import sys
from collections import defaultdict


def events(path):
    out = []
    for line in open(path):
        line = line.strip()
        if line.startswith("{"):
            try:
                out.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    return out


def one_run(run_dir):
    app = events(f"{run_dir}/app.log")
    edits = events(f"{run_dir}/edits.log")
    rows = {}
    for i, edit in enumerate(edits):
        start = edit["written"]
        end = edits[i + 1]["written"] if i + 1 < len(edits) else float("inf")
        window = [e for e in app if start - 50 <= e["t"] < end]
        fs = [e for e in window if e["event"] == "fs-event"]
        done = [e for e in window if e["event"] in ("reloaded", "ignored")]
        errors = [e for e in window if e["event"] == "flutter-error"]
        r = done[0] if done else {}
        rows[edit["case"]] = {
            "write_to_event": fs[0]["t"] - start if fs else None,
            "event_to_frame": r.get("eventToFrameMs"),
            "write_to_frame": r["t"] - start if r.get("event") == "reloaded" else None,
            "slots": ", ".join(r.get("slots", [])) or ("ignored" if r else "—"),
            "status": "; ".join(s.split(" (")[0][:60] for s in r.get("status", [])) or "—",
            "errors": len(errors),
        }
    initial = next((e["ms"] for e in app if e["event"] == "initial-load"), None)
    return rows, initial


def fmt(values):
    values = [v for v in values if v is not None]
    if not values:
        return "—"
    med = int(statistics.median(values))
    return f"{med}" if min(values) == max(values) else f"{med} ({min(values)}–{max(values)})"


def main():
    runs = [one_run(d) for d in sys.argv[1:]]
    cases = list(runs[0][0])
    print(f"Initial load (ms): {fmt([r[1] for r in runs])}\n")
    print("| Case | Reloaded | Status | Write → FS event | FS event → frame | Write → frame | Flutter errors |")
    print("|---|---|---|---|---|---|---|")
    for case in cases:
        col = defaultdict(list)
        for rows, _ in runs:
            for k, v in rows.get(case, {}).items():
                col[k].append(v)
        print(
            f"| {case} | {col['slots'][0]} | {col['status'][0]} | {fmt(col['write_to_event'])} | "
            f"{fmt(col['event_to_frame'])} | {fmt(col['write_to_frame'])} | {sum(col['errors'])} |"
        )


if __name__ == "__main__":
    main()
