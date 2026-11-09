#!/usr/bin/env bash
# Export one complete slow trace and its finding for astrona test.
set -euo pipefail
python3 - <<'PY'
import json
import subprocess
import time
from pathlib import Path

api = '/api/v1/namespaces/observability/services/jaeger:16686/proxy/api/v3/traces'
query = ('?query.service_name=relay&query.start_time_min=2020-01-01T00:00:00Z'
         '&query.start_time_max=2100-01-01T00:00:00Z&query.search_depth=20&query.duration_min=500ms')

def get(path):
    return json.loads(subprocess.check_output(
        ['kubectl', 'get', '--raw', path, '--request-timeout=20s'], text=True, timeout=30))

def spans(document):
    for resource in document.get('result', {}).get('resourceSpans', []):
        service = next(a['value']['stringValue'] for a in resource['resource']['attributes']
                       if a['key'] == 'service.name')
        for scope in resource['scopeSpans']:
            for span in scope['spans']:
                yield service, span

deadline = time.monotonic() + 300
last_error = 'waiting for spans from both services'
while time.monotonic() < deadline:
    try:
        candidates = {s['traceId'] for service, s in spans(get(api + query))
                      if service == 'scout' and s['name'] == 'delayHandler'}
        for trace_id in candidates:
            document = get(api + '/' + trace_id)
            items = {(s['traceId'], s['spanId']): (service, s) for service, s in spans(document)}
            for service, handler in items.values():
                if service != 'scout' or handler['name'] != 'delayHandler':
                    continue
                scout_service, scout = items.get((trace_id, handler.get('parentSpanId')), ('', {}))
                relay_service, client = items.get((trace_id, scout.get('parentSpanId')), ('', {}))
                root_service, root = items.get((trace_id, client.get('parentSpanId')), ('', {}))
                if not (scout_service == 'scout' and scout.get('kind') == 2
                        and relay_service == 'relay' and client.get('kind') == 3
                        and root_service == 'relay' and root.get('kind') == 2):
                    continue
                duration = (int(handler['endTimeUnixNano']) - int(handler['startTimeUnixNano'])) / 1_000_000
                if duration < 900:
                    continue
                report = dict(service=service, name=handler['name'], traceId=trace_id,
                              spanId=handler['spanId'], durationMs=round(duration))
                Path('/tmp/ats020-slow-trace.json').write_text(json.dumps(document, indent=2) + '\n')
                Path('/tmp/ats020-slow-span.json').write_text(json.dumps(report, indent=2) + '\n')
                print(json.dumps(report, indent=2))
                raise SystemExit(0)
    except (ValueError, KeyError, StopIteration, subprocess.SubprocessError) as error:
        last_error = str(error)
    time.sleep(3)
raise SystemExit('No complete slow trace arrived within five minutes: ' + last_error)
PY
