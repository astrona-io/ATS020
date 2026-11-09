#!/usr/bin/env python3
"""Exercise the graders with complete, incomplete, and misleading evidence."""
import contextlib
import copy
import io
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

LAB = Path(__file__).resolve().parents[1]
TRACE = 'a' * 32
ROOT, CLIENT, SERVER, HANDLER = (str(n) * 16 for n in range(1, 5))


def span(span_id, name, kind, parent, start, end):
    return dict(traceId=TRACE, spanId=span_id, name=name, kind=kind,
                parentSpanId=parent, startTimeUnixNano=str(start), endTimeUnixNano=str(end))


def resource(service, spans):
    return dict(resource=dict(attributes=[dict(key='service.name', value=dict(stringValue=service))]),
                scopeSpans=[dict(spans=spans)])


class GraderTests(unittest.TestCase):
    def setUp(self):
        self.live = dict(result=dict(resourceSpans=[
            resource('relay', [span(ROOT, 'GET', 2, None, 0, 1_002_000_000),
                               span(CLIENT, 'GET', 3, ROOT, 500_000, 1_001_500_000)]),
            resource('scout', [span(SERVER, 'GET /delay/{wait:[0-9]+}', 2, CLIENT, 1_000_000, 1_001_000_000),
                               span(HANDLER, 'delayHandler', 1, SERVER, 1_000_000, 1_001_000_000)])]))
        self.evidence = copy.deepcopy(self.live)
        self.report = dict(service='scout', name='delayHandler', traceId=TRACE,
                           spanId=HANDLER, durationMs=1000)

    def run_grader(self, name, expected, missing=None, api_error=False):
        script = (LAB / 'validation' / f'validate-{name}.sh').read_text()
        source = script.split("python3 - <<'PY'\n", 1)[1].rsplit('\nPY', 1)[0]
        files = {'/tmp/ats020-slow-trace.json': self.evidence,
                 '/tmp/ats020-slow-span.json': self.report}

        def read(path, *args, **kwargs):
            if str(path) == missing:
                raise FileNotFoundError(str(path))
            return json.dumps(files[str(path)])

        def query(command, **kwargs):
            self.assertEqual(command[:3], ['kubectl', 'get', '--raw'])
            self.assertTrue(command[3].endswith('/api/v3/traces/' + TRACE))
            if api_error:
                raise subprocess.CalledProcessError(1, command)
            return json.dumps(self.live)

        out, err = io.StringIO(), io.StringIO()
        code = 0
        with patch.object(Path, 'read_text', read), patch('subprocess.check_output', query), \
                contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                exec(compile(source, str(LAB / 'validation' / f'validate-{name}.sh'), 'exec'), {})
            except SystemExit as result:
                code = result.code
        self.assertEqual(code, 0 if expected else 1, out.getvalue() + err.getvalue())
        self.assertIn('PASS:' if expected else 'FAIL:', out.getvalue() + err.getvalue())

    def test_complete_trace_and_correct_finding_pass(self):
        self.run_grader('trace-evidence', True)
        self.run_grader('slow-operation', True)

    def test_missing_files_fail(self):
        self.run_grader('trace-evidence', False, missing='/tmp/ats020-slow-trace.json')
        self.run_grader('slow-operation', False, missing='/tmp/ats020-slow-span.json')

    def test_empty_export_fails(self):
        self.evidence['result']['resourceSpans'] = []
        self.run_grader('trace-evidence', False)

    def test_multiple_traces_fail(self):
        self.evidence['result']['resourceSpans'][1]['scopeSpans'][0]['spans'][0]['traceId'] = 'b' * 32
        self.run_grader('trace-evidence', False)

    def test_partial_export_fails(self):
        self.evidence['result']['resourceSpans'][0]['scopeSpans'][0]['spans'].pop()
        self.run_grader('trace-evidence', False)

    def test_fabricated_timing_fails(self):
        self.evidence['result']['resourceSpans'][1]['scopeSpans'][0]['spans'][1]['endTimeUnixNano'] = '1500000000'
        self.run_grader('trace-evidence', False)

    def test_two_services_without_parent_link_fail(self):
        for document in (self.evidence, self.live):
            document['result']['resourceSpans'][1]['scopeSpans'][0]['spans'][0]['parentSpanId'] = None
        self.run_grader('trace-evidence', False)

    def test_duplicate_span_fails(self):
        spans = self.evidence['result']['resourceSpans'][1]['scopeSpans'][0]['spans']
        spans.append(copy.deepcopy(spans[-1]))
        self.run_grader('trace-evidence', False)

    def test_unavailable_jaeger_fails(self):
        self.run_grader('trace-evidence', False, api_error=True)

    def test_longest_enclosing_span_is_not_the_finding(self):
        self.report.update(service='relay', name='GET', spanId=ROOT, durationMs=1002)
        self.run_grader('slow-operation', False)

    def test_invented_span_identifier_fails(self):
        self.report['spanId'] = 'f' * 16
        self.run_grader('slow-operation', False)

    def test_wrong_trace_identifier_fails(self):
        self.report['traceId'] = 'b' * 32
        self.run_grader('slow-operation', False)

    def test_wrong_duration_or_type_fails(self):
        for duration in (2000, '1000', True, float('nan'), 999.5):
            with self.subTest(duration=duration):
                self.report['durationMs'] = duration
                self.run_grader('slow-operation', False)

    def test_rounding_tolerance(self):
        self.report['durationMs'] = 1001
        self.run_grader('slow-operation', True)


if __name__ == '__main__':
    unittest.main()
