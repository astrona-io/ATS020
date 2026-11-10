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
collector = state['collector']
if 'get --raw' in args and ':8888/proxy/metrics' in args:
    print(state['metrics'])
elif 'get --raw' in args and '/api/v3/traces' in args:
    print(json.dumps(state['jaeger']))
elif 'get pod' in args:
    print('otel-collector-abc')
elif 'opentelemetrycollector otel' in args:
    if collector is None:
        sys.exit(1)
    if sys.argv[-1] == 'json':
        print(json.dumps(collector))
    elif '.spec.mode' in args:
        print(collector['spec']['mode'], end='')
    elif 'pipelines.traces.exporters' in args:
        print(' '.join(collector['spec']['config']['service']['pipelines']['traces']['exporters']), end='')
elif 'service otel-collector' in args:
    print('4317', end='')
elif 'deployment scout' in args:
    print(state['scout_endpoint'], end='')
else:
    sys.exit(1)
'''


def collector(endpoint, insecure):
    exporter = {'endpoint': endpoint}
    if insecure:
        exporter['tls'] = {'insecure': True}
    return {'spec': {'mode': 'deployment', 'config': {
        'receivers': {'otlp/grpc': {'protocols': {'grpc': {'endpoint': '0.0.0.0:4317'}}}},
        'processors': {'batch': {}},
        'exporters': {'otlp_grpc': exporter},
        'service': {'pipelines': {'traces': {
            'receivers': ['otlp/grpc'], 'processors': ['batch'], 'exporters': ['otlp_grpc']}}}}}}


def counters(accepted, sent):
    return (f'otelcol_receiver_accepted_spans{{receiver="otlp/grpc"}} {accepted}\n'
            f'otelcol_exporter_sent_spans{{exporter="otlp_grpc"}} {sent}')


JAEGER_SCOUT = {'result': {'resourceSpans': [{
    'resource': {'attributes': [{'key': 'service.name', 'value': {'stringValue': 'scout'}}]},
    'scopeSpans': [{'spans': [{'spanId': '1'}, {'spanId': '2'}]}]}]}}

# manifests/collector-start.yaml: wrong host, no tls.insecure; spans arrive, none leave.
START = {'collector': collector('jaeger-collector.observability:4317', False),
         'scout_endpoint': 'http://otel-collector.observability:4317',
         'metrics': counters(120, 0), 'jaeger': {'result': {'resourceSpans': []}}}
# solution/solution.yaml
SOLVED = {**START, 'collector': collector('jaeger.observability:4317', True),
          'metrics': counters(120, 118), 'jaeger': JAEGER_SCOUT}


class GraderTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        kubectl = Path(self.tmp.name) / 'kubectl'
        kubectl.write_text(FAKE_KUBECTL)
        kubectl.chmod(kubectl.stat().st_mode | stat.S_IEXEC)
        # Graders retry with sleep; a no-op sleep keeps the test fast.
        sleep = Path(self.tmp.name) / 'sleep'
        sleep.write_text('#!/bin/sh\nexit 0\n')
        sleep.chmod(sleep.stat().st_mode | stat.S_IEXEC)

    def tearDown(self):
        self.tmp.cleanup()

    def grade(self, state):
        path = Path(self.tmp.name) / 'state.json'
        path.write_text(json.dumps(state))
        env = {**os.environ, 'FAKE_STATE': str(path),
               'PATH': f'{self.tmp.name}:{os.environ["PATH"]}'}
        results = {}
        for grader in GRADERS:
            run = subprocess.run(['bash', str(grader)], env=env, capture_output=True, text=True)
            results[grader.name] = (run.returncode, run.stdout + run.stderr)
        return results

    def test_untouched_lab_fails_every_check(self):
        for name, (code, output) in self.grade(START).items():
            self.assertNotEqual(code, 0, f'{name} passed on the untouched lab: {output}')
            self.assertIn('FAIL:', output, name)

    def test_reference_solution_passes_every_check(self):
        for name, (code, output) in self.grade(SOLVED).items():
            self.assertEqual(code, 0, f'{name} failed on the solution: {output}')

    def test_host_fixed_without_tls_passes_only_the_endpoint_check(self):
        state = {**START, 'collector': collector('jaeger.observability:4317', False)}
        results = self.grade(state)
        self.assertEqual(results['validate-exporter-endpoint.sh'][0], 0)
        self.assertNotEqual(results['validate-collector-counters.sh'][0], 0)
        self.assertNotEqual(results['validate-trace-in-jaeger.sh'][0], 0)

    def test_other_service_names_for_jaeger_pass(self):
        for endpoint in ('jaeger:4317', 'dns:///jaeger.observability.svc.cluster.local:4317'):
            state = {**SOLVED, 'collector': collector(endpoint, True)}
            self.assertEqual(self.grade(state)['validate-exporter-endpoint.sh'][0], 0, endpoint)

    def test_scout_bypass_fails_every_check(self):
        state = {**SOLVED, 'scout_endpoint': 'http://jaeger.observability:4317'}
        for name, (code, _) in self.grade(state).items():
            self.assertNotEqual(code, 0, name)

    def test_debug_only_exporter_fails_every_check(self):
        state = copy.deepcopy(SOLVED)
        state['collector']['spec']['config']['exporters'] = {'debug': {}}
        state['collector']['spec']['config']['service']['pipelines']['traces']['exporters'] = ['debug']
        for name, (code, _) in self.grade(state).items():
            self.assertNotEqual(code, 0, name)

    def test_deleted_collector_fails_every_check(self):
        for name, (code, _) in self.grade({**SOLVED, 'collector': None}).items():
            self.assertNotEqual(code, 0, name)


if __name__ == '__main__':
    unittest.main()
