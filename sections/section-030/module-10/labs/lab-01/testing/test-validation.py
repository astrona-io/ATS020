#!/usr/bin/env python3
"""Run every grader against a fake cluster: the untouched lab must fail every
check, the reference solution must pass every check, and a bypass must fail."""
import copy
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest

LAB = Path(__file__).resolve().parents[1]
GRADERS = sorted((LAB / 'validation').glob('validate-*.sh'))

FAKE_KUBECTL = r'''#!/usr/bin/env python3
import json, os, sys
state = json.load(open(os.environ['FAKE_STATE']))
args = ' '.join(sys.argv[1:])
if 'get --raw' in args and '/api/v3/traces' in args:
    print(json.dumps(state['jaeger']))
elif 'deployment probe' in args and state['deployment'] is not None:
    print(json.dumps(state['deployment']))
else:
    sys.exit(1)
'''


def deployment(enabled, endpoint, target='http://relay.outpost:8080', rolled_out=True):
    env = {'TRACE_SERVICE': 'probe', 'TARGET_URL': target,
           'OTEL_ENABLED': enabled, 'OTEL_EXPORTER_OTLP_ENDPOINT': endpoint}
    return {'metadata': {'generation': 2},
            'spec': {'replicas': 1, 'template': {'spec': {'containers': [
                {'name': 'probe', 'env': [{'name': k, 'value': v} for k, v in env.items()]}]}}},
            'status': {'observedGeneration': 2 if rolled_out else 1, 'replicas': 1,
                       'updatedReplicas': 1 if rolled_out else 0, 'readyReplicas': 1}}


def attributes(pairs):
    return [{'key': k, 'value': {'stringValue': v}} for k, v in pairs.items()]


EVENT = {'timeUnixNano': '1', 'name': 'exception', 'attributes': attributes({
    'exception.type': 'URLError',
    'exception.message': '<urlopen error [Errno -2] Name does not resolve>',
    'exception.stacktrace': 'Traceback (most recent call last): ...'})}

JAEGER_PROBE = {'result': {'resourceSpans': [{
    'resource': {'attributes': attributes({'service.name': 'probe'})},
    'scopeSpans': [{'spans': [{'spanId': '1', 'status': {'code': 2}, 'events': [EVENT]}]}]}]}}

# manifests/lab-start.yaml: tracing off, wrong namespace, no spans, no file.
START = {'deployment': deployment('false', 'http://jaeger.observability:4318'),
         'jaeger': {'error': {'httpCode': 404, 'message': 'trace not found'}},
         'export': None}
# solution/apply.sh
SOLVED = {'deployment': deployment('true', 'http://jaeger.tracing:4318'),
          'jaeger': JAEGER_PROBE, 'export': [EVENT]}


class GraderTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        for name, body in (('kubectl', FAKE_KUBECTL), ('sleep', '#!/bin/sh\nexit 0\n')):
            # Graders retry with sleep; a no-op sleep keeps the test fast.
            tool = Path(self.tmp.name) / name
            tool.write_text(body)
            tool.chmod(tool.stat().st_mode | stat.S_IEXEC)

    def tearDown(self):
        self.tmp.cleanup()

    def grade(self, state):
        path = Path(self.tmp.name) / 'state.json'
        path.write_text(json.dumps(state))
        export = Path(self.tmp.name) / 'exception.json'
        export.unlink(missing_ok=True)
        if state['export'] is not None:
            export.write_text(json.dumps(state['export']))
        env = {**os.environ, 'FAKE_STATE': str(path), 'ATS_EXCEPTION_FILE': str(export),
               'PATH': f'{self.tmp.name}:{os.environ["PATH"]}'}
        results = {}
        for grader in GRADERS:
            run = subprocess.run(['bash', str(grader)], env=env, capture_output=True, text=True)
            results[grader.name] = (run.returncode, run.stdout + run.stderr)
        return results

    def assert_only_passes(self, state, passing):
        for name, (code, output) in self.grade(state).items():
            if name in passing:
                self.assertEqual(code, 0, f'{name} failed: {output}')
            else:
                self.assertNotEqual(code, 0, f'{name} passed: {output}')

    def test_untouched_lab_fails_every_check(self):
        for name, (code, output) in self.grade(START).items():
            self.assertNotEqual(code, 0, f'{name} passed on the untouched lab: {output}')
            self.assertIn('FAIL:', output, name)

    def test_reference_solution_passes_every_check(self):
        for name, (code, output) in self.grade(SOLVED).items():
            self.assertEqual(code, 0, f'{name} failed on the solution: {output}')

    def test_enabled_only_passes_only_the_enabled_check(self):
        state = {**START, 'deployment': deployment('true', 'http://jaeger.observability:4318')}
        self.assert_only_passes(state, {'validate-otel-enabled.sh'})

    def test_endpoint_only_passes_only_the_endpoint_check(self):
        state = {**START, 'deployment': deployment('false', 'http://jaeger.tracing:4318')}
        self.assert_only_passes(state, {'validate-exporter-endpoint.sh'})

    def test_unfinished_rollout_fails_the_enabled_check(self):
        state = {**SOLVED, 'deployment': deployment('true', 'http://jaeger.tracing:4318', rolled_out=False)}
        self.assertNotEqual(self.grade(state)['validate-otel-enabled.sh'][0], 0)

    def test_other_names_for_the_jaeger_service_pass(self):
        for endpoint in ('http://jaeger.tracing.svc:4318', 'http://jaeger.tracing.svc.cluster.local:4318/'):
            state = {**SOLVED, 'deployment': deployment('true', endpoint)}
            self.assertEqual(self.grade(state)['validate-exporter-endpoint.sh'][0], 0, endpoint)

    def test_wrong_endpoints_fail(self):
        for endpoint in ('http://jaeger:4318', 'http://jaeger.tracing:4317',
                         'http://jaeger.tracing:4318/v1/traces', 'jaeger.tracing:4318'):
            state = {**SOLVED, 'deployment': deployment('true', endpoint)}
            self.assertNotEqual(self.grade(state)['validate-exporter-endpoint.sh'][0], 0, endpoint)

    def test_changed_target_url_fails_every_check(self):
        state = {**SOLVED, 'deployment': deployment('true', 'http://jaeger.tracing:4318', target='http://example.com')}
        for name, (code, _) in self.grade(state).items():
            self.assertNotEqual(code, 0, name)

    def test_deleted_deployment_fails_every_check(self):
        for name, (code, _) in self.grade({**SOLVED, 'deployment': None}).items():
            self.assertNotEqual(code, 0, name)

    def test_hand_written_exception_fails_the_export_check(self):
        event = copy.deepcopy(EVENT)
        event['attributes'][1]['value']['stringValue'] = 'made up'
        state = {**SOLVED, 'export': [event]}
        self.assertNotEqual(self.grade(state)['validate-exception-exported.sh'][0], 0)

    def test_whole_api_response_fails_the_export_check(self):
        state = {**SOLVED, 'export': JAEGER_PROBE}
        self.assertNotEqual(self.grade(state)['validate-exception-exported.sh'][0], 0)


if __name__ == '__main__':
    unittest.main()
