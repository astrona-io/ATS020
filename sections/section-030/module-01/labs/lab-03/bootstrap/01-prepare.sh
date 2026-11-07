#!/usr/bin/env bash
# Astrona supplies kubectl. Check the terminal prerequisites before setup.
set -euo pipefail
for tool in kubectl curl jq; do
  command -v "$tool" >/dev/null || { echo "Missing terminal prerequisite: $tool" >&2; exit 1; }
done
# Files from an earlier attempt must not count as this attempt's answers.
rm -f /tmp/ats-020-error-service.txt /tmp/ats-020-exceptions.json
