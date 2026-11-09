#!/usr/bin/env python3
"""Write the versions from versions.env into the course files.

Usage:
  scripts/sync-versions.py [--check] [--env FILE] [PATH ...]

Without PATH it syncs every file and directory listed on the "Synced paths:"
line of versions.env. With --check it changes nothing, prints every line that holds
another version and exits 1 if there is one (use it in CI).

Each rule below finds one way a version is written (an image tag, a release
URL, a shell variable, a sentence such as "Jaeger 2.22.0") and replaces only
the version inside it. A version that no rule matches is left alone, so a new
way of writing a version needs a new rule here. A tag that is wrong on purpose
(a fault a lab asks the learner to find) is listed in FAULTS and never changed.
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
    ("OTEL_OPERATOR_VERSION", rf"(?<!Prometheus\s)Operator{GAP}(?P<v>{SEMVER}){HISTORY}", same),
    # kubectl get opentelemetrycollector: the VERSION column is the Operator.
    ("OTEL_OPERATOR_VERSION", rf"(?:deployment|daemonset|sidecar|statefulset)\s+(?P<v>{SEMVER})\s+\d+/\d+", same),
    ("OTEL_OPERATOR_VERSION", rf"`(?P<v>{SEMVER})` is the version of the Operator", same),
    # OpenTelemetry Collector contrib and telemetrygen
    ("OTEL_COLLECTOR_VERSION", rf"opentelemetry-collector-contrib:(?P<v>{SEMVER})", same),
    ("OTEL_COLLECTOR_VERSION", rf"telemetrygen:v(?P<v>{SEMVER})", same),
    ("OTEL_COLLECTOR_VERSION", rf"\b[a-z]+@v(?P<v>{SEMVER})/", same),  # Collector log lines
    ("OTEL_COLLECTOR_VERSION", rf"contrib(?:\s+image)?{GAP}(?P<v>{SEMVER}){HISTORY}", same),
    ("OTEL_COLLECTOR_VERSION", rf"shows the Collector, `(?P<v>{SEMVER})`", same),
    # Section 020: "version 0.162.0 still accepts the old name", "still work in version 0.162.0".
    ("OTEL_COLLECTOR_VERSION", rf"[Vv]ersion\s+(?P<v>{SEMVER})(?=\s+(?:still\s+)?(?:accepts|prints))", same),
    ("OTEL_COLLECTOR_VERSION", rf"work\s+in\s+version\s+(?P<v>{SEMVER})", same),
    # Jaeger
    ("JAEGER_VERSION", rf"jaegertracing/jaeger:(?P<v>{SEMVER})", same),
    ("JAEGER_VERSION", rf"Jaeger{GAP}(?P<v>{SEMVER}){HISTORY}", same),
    ("JAEGER_VERSION", rf"pinned\s+(?P<v>{SEMVER})\s+playground", same),
    ("JAEGER_VERSION", rf"jaegertracing/jaeger/blob/v(?P<v>{SEMVER})/", same),  # astrona.yaml resources
    # podinfo (scout)
    ("PODINFO_VERSION", rf"stefanprodan/podinfo:v?(?P<v>{SEMVER})", same),
    ("PODINFO_VERSION", rf"podinfo`?{GAP}(?P<v>{SEMVER}){HISTORY}", same),
    # Section 040 seeds a Git history that deploys podinfo (good and missing tag).
    ("PODINFO_VERSION", rf'(?:GOOD|BAD)="(?P<v>{SEMVER})', same),
    ("PODINFO_VERSION", rf"Start scout (?P<v>{SEMVER})", same),
    ("PODINFO_VERSION", rf"`(?P<v>{SEMVER})-missing`", same),
    # Section 050 talks about the beacon (podinfo) tag. No other tool's tag is
    # written as "tag X" in the course; check that before you add one.
    ("PODINFO_VERSION", rf"\btag(?:\s+is)?\s+`?v?(?P<v>{SEMVER})", same),
    # curl (shuttle)
    ("CURL_VERSION", rf"curlimages/curl:(?P<v>{SEMVER})", same),
    ("CURL_VERSION", rf"user_agent=curl/(?P<v>{SEMVER})", same),  # go-httpbin log lines
    # Python trace emitter
    ("PYTHON_IMAGE_TAG", r"\bpython:(?P<v>\d+\.\d+\.\d+-alpine\d+\.\d+)", same),
    # relay (Node.js)
    ("NODE_IMAGE_TAG", r"(?<![\w/-])node:(?P<v>\d+-alpine)", same),
    # go-httpbin (probe)
    ("GO_HTTPBIN_VERSION", rf"go-httpbin:(?P<v>{SEMVER})", same),
    ("GO_HTTPBIN_VERSION", rf"httpbin`?{GAP}(?P<v>{SEMVER}){HISTORY}", same),
    # Helm
    ("HELM_VERSION", rf'HELM_VERSION="v(?P<v>{SEMVER})"', same),
    ("HELM_VERSION", rf"Helm{GAP}(?P<v>{SEMVER}){HISTORY}", same),
    ("HELM_VERSION", rf'helm version --short \| grep -q "\^v(?P<v>{SEMVER})"', same),
    # kube-prometheus-stack chart and the images it installs
    ("KUBE_PROMETHEUS_STACK_VERSION", rf'CHART_VERSION="(?P<v>{SEMVER})"', same),
    ("KUBE_PROMETHEUS_STACK_VERSION", rf"kube-prometheus-stack`?(?:\s+(?:Helm\s+)?chart)?{GAP}(?P<v>{SEMVER}){HISTORY}", same),
    ("PROMETHEUS_VERSION", rf"prometheus/prometheus:v(?P<v>{SEMVER})", same),
    ("PROMETHEUS_VERSION", rf"Prometheus{GAP}v?(?P<v>{SEMVER}){HISTORY}", same),
    ("PROMETHEUS_VERSION", rf"Prometheus{GAP}(?P<v>\d+\.\d+)(?!\.?\d)", minor),
    # "one Prometheus server (version 3.15.0", "Prometheus runs version 3.15.0"
    ("PROMETHEUS_VERSION", rf"Prometheus(?:\s+server)?(?:,\s+|\s+runs\s+|\s+\()version\s+(?P<v>{SEMVER})", same),
    ("PROMETHEUS_VERSION", rf"kps-prometheus\s+v(?P<v>{SEMVER})-distroless", same),  # kubectl get prometheus
    ("PROMETHEUS_VERSION", rf"prometheus/prometheus/blob/v(?P<v>{SEMVER})/", same),  # astrona.yaml resources
    ("PROMETHEUS_OPERATOR_VERSION", rf"prometheus-operator/prometheus-(?:operator|config-reloader):v(?P<v>{SEMVER})", same),
    ("PROMETHEUS_OPERATOR_VERSION", rf"Prometheus\s+Operator{GAP}v?(?P<v>{SEMVER}){HISTORY}", same),
    ("PROMETHEUS_OPERATOR_VERSION", rf"(?:`kps-operator`,|operator\s+runs)\s+version\s+(?P<v>{SEMVER})", same),
    ("ALERTMANAGER_VERSION", rf"prometheus/alertmanager:v(?P<v>{SEMVER})", same),
    ("ALERTMANAGER_VERSION", rf"Alertmanager{GAP}v?(?P<v>{SEMVER}){HISTORY}", same),
    ("ALERTMANAGER_VERSION", rf"Alertmanager\s+\(version\s+(?P<v>{SEMVER})", same),
    ("GRAFANA_VERSION", rf"grafana/grafana:(?P<v>{SEMVER})", same),
    ("GRAFANA_VERSION", rf"Grafana{GAP}(?P<v>{SEMVER}){HISTORY}", same),
    ("GRAFANA_VERSION", rf"Grafana{GAP}(?P<v>\d+\.\d+)(?!\.?\d)", minor),
    # The /api/health answer of Grafana. No other JSON in the course has "version".
    ("GRAFANA_VERSION", rf'"version":\s*"(?P<v>{SEMVER})"', same),
    ("K8S_SIDECAR_VERSION", rf"kiwigrid/k8s-sidecar:(?P<v>{SEMVER})", same),
    ("KUBE_WEBHOOK_CERTGEN_VERSION", rf"jkroepke/kube-webhook-certgen:(?P<v>{SEMVER})", same),
    # Loki
    ("LOKI_VERSION", rf"grafana/loki:(?P<v>{SEMVER})", same),
    ("LOKI_VERSION", rf"Loki{GAP}(?P<v>{SEMVER}){HISTORY}", same),
    # Argo CD and the Redis image of its install manifest
    ("ARGOCD_VERSION", rf'ARGOCD_VERSION="v(?P<v>{SEMVER})"', same),
    ("ARGOCD_VERSION", rf"argoproj/argocd:v(?P<v>{SEMVER})", same),
    ("ARGOCD_VERSION", rf"Argo\s+CD{GAP}v?(?P<v>{SEMVER}){HISTORY}", same),
    ("ARGOCD_REDIS_VERSION", rf"library/redis:(?P<v>{SEMVER})", same),
    # Gitea
    ("GITEA_VERSION", rf"gitea/gitea:(?P<v>{SEMVER})", same),
    ("GITEA_VERSION", rf"Gitea{GAP}(?P<v>{SEMVER}){HISTORY}", same),
    # metrics-server
    ("METRICS_SERVER_VERSION", rf"metrics-server`?{GAP}(?P<v>{SEMVER}){HISTORY}", same),
]

# README.md lists the versions as "**name version**".
README_KEYS = {
    "kube_prometheus_stack_chart": "KUBE_PROMETHEUS_STACK_VERSION",
    "metrics_server": "METRICS_SERVER_VERSION",
    "grafana": "GRAFANA_VERSION",
    "opentelemetry_operator": "OTEL_OPERATOR_VERSION",
    "opentelemetry_collector": "OTEL_COLLECTOR_VERSION",
    "jaeger": "JAEGER_VERSION",
    "cert_manager": "CERT_MANAGER_VERSION",
    "argo_cd": "ARGOCD_VERSION",
    "gitea": "GITEA_VERSION",
    "helm": "HELM_VERSION",
    "podinfo": "PODINFO_VERSION",
    "go_httpbin": "GO_HTTPBIN_VERSION",
}
RULES += [(key, rf"\*\*{name} (?P<v>{SEMVER})\*\*", same) for name, key in README_KEYS.items()]
RULES.append(("KIND_NODE_VERSION", r"\*\*kubernetes (?P<v>\d+\.\d+)\*\*", minor))

# Tags that are wrong on purpose: a fault a learner must find (section 050
# uses a podinfo tag that does not exist). The sync never changes them.
FAULTS = {
    "PODINFO_VERSION": {"6.15.99"},
}


def read_env(path):
    values, synced = {}, []
    for line in path.read_text().splitlines():
        if line.startswith("# Synced paths:"):
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
            if have in FAULTS.get(key, ()):
                return match.group(0)
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
        sys.exit("no paths given and no 'Synced paths:' line in versions.env")

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
