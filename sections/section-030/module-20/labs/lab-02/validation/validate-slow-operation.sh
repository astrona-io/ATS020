#!/usr/bin/env bash
# Check the finding against the exported span; the other grader verifies Jaeger.
set -euo pipefail
python3 - <<'PY'
import json
import math
import sys
from pathlib import Path

try:
    report = json.loads(Path('/tmp/ats020-slow-span.json').read_text())
    evidence = json.loads(Path('/tmp/ats020-slow-trace.json').read_text())
    if report['service'] != 'scout' or report['name'] != 'delayHandler':
        raise ValueError('identify the internal downstream operation that explains the wait')
    matches = []
    for resource in evidence['result']['resourceSpans']:
        service = next(a['value']['stringValue'] for a in resource['resource']['attributes']
                       if a['key'] == 'service.name')
        for scope in resource['scopeSpans']:
            for span in scope['spans']:
                if (service == report['service'] and span['name'] == report['name']
                        and span['traceId'] == report['traceId'] and span['spanId'] == report['spanId']
                        and span['kind'] == 1):
                    matches.append(span)
    if len(matches) != 1:
        raise ValueError('the finding must identify one internal span in your saved trace')
    span = matches[0]
    duration = (int(span['endTimeUnixNano']) - int(span['startTimeUnixNano'])) / 1_000_000
    measured = report['durationMs']
    if (type(measured) not in (int, float) or not math.isfinite(measured)
            or measured != round(measured) or duration < 900 or abs(measured - duration) > 1):
        raise ValueError('durationMs must be the slow span duration rounded to whole milliseconds')
    print(f'PASS: scout {span["name"]} accounts for {measured:.0f} ms in the saved trace')
except (OSError, ValueError, KeyError, TypeError, StopIteration) as error:
    print(f'FAIL: {error}', file=sys.stderr)
    sys.exit(1)
PY
