#!/usr/bin/env bash
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
kubectl -n argocd get application scout -o json | jq '.status.history' > "$work/history.json"
kubectl -n gitea exec deploy/gitea -- curl -fsS 'http://localhost:3000/api/v1/repos/starfleet/starfleet-deploy/commits?limit=20&stat=false&verification=false&files=false' > "$work/commits.json"
python3 - "$lab_dir/validation" "$work" restore <<'REPORT'
import json, pathlib, sys
sys.path.insert(0, sys.argv[1])
from durations import calculate
p = pathlib.Path(sys.argv[2])
report = calculate(json.loads((p/'history.json').read_text()), json.loads((p/'commits.json').read_text()), sys.argv[3])
(p/'report.json').write_text(json.dumps(report))
REPORT
kubectl -n starfleet create configmap delivery-evidence --from-file=report.json="$work/report.json" --dry-run=client -o yaml | kubectl apply -f -
