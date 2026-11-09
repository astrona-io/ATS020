#!/usr/bin/env bash
# Compare the learner's exported trace with live Jaeger data, without changing it.
set -euo pipefail
python3 - <<'PY'
import json
import re
import subprocess
import sys
from pathlib import Path

def require(condition, message):
    if not condition:
        raise ValueError(message)

def spans(document):
    result = {}
    for resource in document['result']['resourceSpans']:
        service = next(a['value']['stringValue'] for a in resource['resource']['attributes']
                       if a['key'] == 'service.name')
        for scope in resource['scopeSpans']:
            for span in scope['spans']:
                key = (span['traceId'], span['spanId'])
                require(key not in result, 'the export contains duplicate spans')
                result[key] = (service, span)
    return result

def signature(item):
    service, span = item
    return (service, span['name'], span['kind'], span.get('parentSpanId') or '',
            int(span['startTimeUnixNano']), int(span['endTimeUnixNano']))

try:
    saved = spans(json.loads(Path('/tmp/ats020-slow-trace.json').read_text()))
    ids = {key[0] for key in saved}
    require(len(ids) == 1, 'export exactly one nonempty trace')
    trace_id = next(iter(ids))
    require(re.fullmatch(r'[0-9a-f]{32}', trace_id), 'the trace identifier must be 32 hexadecimal characters')
    url = '/api/v1/namespaces/observability/services/jaeger:16686/proxy/api/v3/traces/' + trace_id
    live = spans(json.loads(subprocess.check_output(
        ['kubectl', 'get', '--raw', url, '--request-timeout=20s'], text=True, timeout=30)))
    require(saved.keys() == live.keys(), 'the export does not contain all spans of this trace in Jaeger')
    require(all(signature(item) == signature(live[key]) for key, item in saved.items()),
            'exported service names, operations, parents, kinds, or timestamps differ from Jaeger')

    # Follow the internal handler back through both request spans to relay's root.
    linked = False
    for service, handler in saved.values():
        if service != 'scout' or handler['name'] != 'delayHandler' or handler['kind'] != 1:
            continue
        require(int(handler['endTimeUnixNano']) - int(handler['startTimeUnixNano']) >= 900_000_000,
                'the selected handler does not show a slow request')
        scout_service, scout = saved.get((trace_id, handler.get('parentSpanId')), ('', {}))
        relay_service, client = saved.get((trace_id, scout.get('parentSpanId')), ('', {}))
        root_service, root = saved.get((trace_id, client.get('parentSpanId')), ('', {}))
        linked = (scout_service == 'scout' and scout.get('kind') == 2
                  and relay_service == 'relay' and client.get('kind') == 3
                  and root_service == 'relay' and root.get('kind') == 2
                  and not root.get('parentSpanId'))
        if linked:
            break
    require(linked, 'the trace must link relay server → relay client → scout server → slow internal handler')
    print(f'PASS: exported trace {trace_id} matches Jaeger and contains the complete request chain')
except (OSError, ValueError, KeyError, TypeError, StopIteration, subprocess.SubprocessError) as error:
    print(f'FAIL: {error}', file=sys.stderr)
    sys.exit(1)
PY
