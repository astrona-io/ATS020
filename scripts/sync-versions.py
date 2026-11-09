#!/usr/bin/env python3
"""Write the versions from versions.env into the course files.

Usage:
  scripts/sync-versions.py [--check] [--env FILE] [PATH ...]

Without PATH it syncs every directory listed on the "Synced so far:" line of
versions.env. With --check it changes nothing, prints every line that holds
another version and exits 1 if there is one (use it in CI).

Each rule below finds one way a version is written (an image tag, a release
URL, a shell variable, a sentence such as "Jaeger 2.22.0") and replaces only
the version inside it. A version that no rule matches is left alone, so a new
way of writing a version needs a new rule here.
"""

import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SEMVER = r"\d+\.\d+\.\d+"
SUFFIXES = {".md", ".yaml", ".yml", ".sh", ".json", ".txt"}
# A version in a sentence about history ("Jaeger 2.21.0 removed both routes")
# is a fact, not the pinned version. Prose rules skip a version that is
# followed by one of these words.
HISTORY = r"(?!\s+(?:removed|added|introduced|deprecated|changed|dropped)\b)"
# Space between a name and its version in prose. It may cross a line break,
# also inside a "#" comment, and allow bold markers ("**1.35**").
GAP = r"\s+(?:#\s+)?\**"

# (variable in versions.env, pattern with a group named "v", transform)
# The transform turns the value from versions.env into the text to write.
same = lambda value: value
minor = lambda value: ".".join(value.split(".")[:2])

RULES = [
    # Kubernetes: kind node image, full version, then the minor version.
    ("KIND_NODE_VERSION", rf"kindest/node:v(?P<v>{SEMVER})", same),
    ("KIND_NODE_VERSION", rf"Kubernetes{GAP}(?P<v>{SEMVER}){HISTORY}", same),
    ("KIND_NODE_VERSION", rf"Kubernetes{GAP}(?P<v>\d+\.\d+)(?!\.?\d)", minor),
    # cert-manager
    ("CERT_MANAGER_VERSION", rf"jetstack/cert-manager-[a-z]+:v(?P<v>{SEMVER})", same),
    ("CERT_MANAGER_VERSION", rf'CERT_MANAGER_VERSION="v(?P<v>{SEMVER})"', same),
    ("CERT_MANAGER_VERSION", rf"cert-manager{GAP}(?P<v>{SEMVER}){HISTORY}", same),
    # OpenTelemetry Operator
    ("OTEL_OPERATOR_VERSION", rf"opentelemetry-operator/opentelemetry-operator:(?P<v>{SEMVER})", same),
    ("OTEL_OPERATOR_VERSION", rf'OTEL_OPERATOR_VERSION="v(?P<v>{SEMVER})"', same),
    ("OTEL_OPERATOR_VERSION", rf"Operator{GAP}(?P<v>{SEMVER}){HISTORY}", same),
    # kubectl get opentelemetrycollector: the VERSION column is the Operator.
    ("OTEL_OPERATOR_VERSION", rf"(?:deployment|daemonset|sidecar|statefulset)\s+(?P<v>{SEMVER})\s+\d+/\d+", same),
    ("OTEL_OPERATOR_VERSION", rf"`(?P<v>{SEMVER})` is the version of the Operator", same),
    # OpenTelemetry Collector contrib and telemetrygen
    ("OTEL_COLLECTOR_VERSION", rf"opentelemetry-collector-contrib:(?P<v>{SEMVER})", same),
    ("OTEL_COLLECTOR_VERSION", rf"telemetrygen:v(?P<v>{SEMVER})", same),
    ("OTEL_COLLECTOR_VERSION", rf"\b[a-z]+@v(?P<v>{SEMVER})/", same),  # Collector log lines
    ("OTEL_COLLECTOR_VERSION", rf"contrib(?:\s+image)?{GAP}(?P<v>{SEMVER}){HISTORY}", same),
    ("OTEL_COLLECTOR_VERSION", rf"shows the Collector, `(?P<v>{SEMVER})`", same),
    # Jaeger
    ("JAEGER_VERSION", rf"jaegertracing/jaeger:(?P<v>{SEMVER})", same),
    ("JAEGER_VERSION", rf"Jaeger{GAP}(?P<v>{SEMVER}){HISTORY}", same),
    ("JAEGER_VERSION", rf"pinned\s+(?P<v>{SEMVER})\s+playground", same),
    # podinfo (scout)
    ("PODINFO_VERSION", rf"stefanprodan/podinfo:(?P<v>{SEMVER})", same),
    ("PODINFO_VERSION", rf"podinfo`?{GAP}(?P<v>{SEMVER}){HISTORY}", same),
    # curl (shuttle)
    ("CURL_VERSION", rf"curlimages/curl:(?P<v>{SEMVER})", same),
    # Python trace emitter
    ("PYTHON_IMAGE_TAG", r"\bpython:(?P<v>\d+\.\d+\.\d+-alpine\d+\.\d+)", same),
    # relay (Node.js)
    ("NODE_IMAGE_TAG", r"(?<![\w/-])node:(?P<v>\d+-alpine)", same),
]


def read_env(path):
    values, synced = {}, []
    for line in path.read_text().splitlines():
        if line.startswith("# Synced so far:"):
            synced = line.split(":", 1)[1].split()
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, _, value = line.partition("=")
        values[key.strip()] = value.strip()
    return values, synced


def sync_text(text, values):
    changes = []
    for key, pattern, transform in RULES:
        if key not in values:
            continue
        want = transform(values[key])

        def replace(match):
            have = match.group("v")
            if have != want:
                line = text.count("\n", 0, match.start("v")) + 1
                changes.append((line, key, have, want))
            start = match.start("v") - match.start()
            end = match.end("v") - match.start()
            whole = match.group(0)
            return whole[:start] + want + whole[end:]

        text = re.sub(pattern, replace, text)
    return text, changes


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true", help="change nothing, exit 1 on a mismatch")
    parser.add_argument("--env", default=str(ROOT / "versions.env"))
    parser.add_argument("paths", nargs="*")
    args = parser.parse_args()

    values, synced = read_env(pathlib.Path(args.env))
    paths = args.paths or [str(ROOT / p) for p in synced]
    if not paths:
        sys.exit("no paths given and no 'Synced so far:' line in versions.env")

    total = 0
    for base in paths:
        base = pathlib.Path(base)
        files = [base] if base.is_file() else sorted(base.rglob("*"))
        for path in files:
            if not path.is_file() or path.suffix not in SUFFIXES:
                continue
            old = path.read_text()
            new, changes = sync_text(old, values)
            for line, key, have, want in changes:
                print(f"{path.relative_to(ROOT) if path.is_relative_to(ROOT) else path}:{line}: {key} {have} -> {want}")
            total += len(changes)
            if new != old and not args.check:
                path.write_text(new)

    if args.check:
        if total:
            print(f"{total} version(s) differ from versions.env. Run scripts/sync-versions.py.")
            sys.exit(1)
        print("all versions match versions.env")
    else:
        print(f"updated {total} version(s)")


if __name__ == "__main__":
    main()
