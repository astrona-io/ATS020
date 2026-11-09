#!/usr/bin/env bash
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
kubectl -n argocd get application scout -o json | jq '.status.history' > "$work/history.json"
kubectl -n gitea exec deploy/gitea -- curl -fsS 'http://localhost:3000/api/v1/repos/starfleet/starfleet-deploy/commits?limit=20&stat=false&verification=false&files=false' > "$work/commits.json"
kubectl -n starfleet get configmap delivery-evidence -o jsonpath='{.data.report\.json}' > "$work/report.json" 2>/dev/null || { echo 'FAIL: submit delivery-evidence'; exit 1; }
python3 - "$lab_dir/validation" "$work" lead <<'CHECK'
import json, pathlib, sys
sys.path.insert(0, sys.argv[1])
from durations import calculate, verify
p = pathlib.Path(sys.argv[2])
try:
    read = lambda name: json.loads((p / name).read_text())
    verify(read('report.json'), calculate(read('history.json'), read('commits.json'), sys.argv[3]))
except (ValueError, KeyError, TypeError, IndexError) as error:
    print(f'FAIL: {error}')
    sys.exit(1)
print('PASS: every duration and the mean match the live timestamps')
CHECK
