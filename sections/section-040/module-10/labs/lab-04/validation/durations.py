"""Compute delivery durations from deployment history and Git commit timestamps."""
import datetime
import math

def seconds(value):
    return datetime.datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()

def calculate(history, commits, mode):
    if len(history) != 10 or {h["id"] for h in history} != set(range(10)):
        raise ValueError("expected ten seeded deployment revisions")
    by_sha = {c["sha"]: c for c in commits}
    by_id = {h["id"]: h for h in history}
    if mode == "lead":
        rows = [{"id": h["id"], "revision": h["revision"], "seconds":
                 seconds(h["deployedAt"]) - seconds(by_sha[h["revision"]]["commit"]["committer"]["date"])}
                for h in sorted(history, key=lambda h: h["id"])]
    else:
        rows = [{"failed_id": bad, "restored_id": fixed, "seconds":
                 seconds(by_id[fixed]["deployedAt"]) - seconds(by_id[bad]["deployedAt"])}
                for bad, fixed in [(2, 3), (6, 7)]]
    if any(r["seconds"] < 0 for r in rows):
        raise ValueError("durations must be nonnegative")
    return {"measurements": rows, "mean_seconds": sum(r["seconds"] for r in rows) / len(rows)}

def verify(actual, expected):
    if not isinstance(actual, dict) or set(actual) != set(expected):
        raise ValueError("submit measurements and mean_seconds")
    rows = actual["measurements"]
    if not isinstance(rows, list) or len(rows) != len(expected["measurements"]):
        raise ValueError("include every measurement")
    for got, want in zip(rows, expected["measurements"]):
        if not isinstance(got, dict) or set(got) != set(want):
            raise ValueError("measurement fields differ")
        for key in want:
            if key == "seconds":
                close(got[key], want[key])
            elif got[key] != want[key]:
                raise ValueError("revision or history id differs")
    close(actual["mean_seconds"], expected["mean_seconds"])

def close(actual, expected):
    if isinstance(actual, bool) or not isinstance(actual, (int, float)) or not math.isfinite(actual) or abs(actual - expected) > 1:
        raise ValueError("duration differs from source timestamps")
