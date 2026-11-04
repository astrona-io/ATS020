#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for candidate in "$script_dir/../validation/validate-targets-up.sh" ./validation/validate-targets-up.sh; do
  if [ -f "$candidate" ]; then bash "$candidate"; exit; fi
done
echo 'Cannot find target validator' >&2
exit 1
