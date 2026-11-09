import copy
import importlib.util
from pathlib import Path
import unittest
spec = importlib.util.spec_from_file_location("durations", Path(__file__).resolve().parents[1]/"validation/durations.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.history = [{"id": i, "revision": str(i), "deployedAt": f"2026-01-01T00:{i:02d}:30Z"} for i in range(10)]
        self.commits = [{"sha": str(i), "commit": {"committer": {"date": f"2026-01-01T00:{i:02d}:00Z"}}} for i in range(10)]
    def test_join_uses_revision_not_list_position(self):
        report = m.calculate(self.history[::-1], self.commits[::-1], 'lead')
        self.assertEqual(report['mean_seconds'], 30)
        self.assertEqual(report['measurements'][0]['revision'], '0')
    def test_restore_uses_ids_not_list_position(self):
        self.assertEqual(m.calculate(self.history[::-1], self.commits, 'restore')['mean_seconds'], 60)
    def test_reject_invalid_evidence(self):
        want = m.calculate(self.history, self.commits, 'lead')
        for value in [float('nan'), float('inf'), True, '30', 50]:
            got = copy.deepcopy(want); got['mean_seconds'] = value
            with self.assertRaises(ValueError): m.verify(got, want)
        for key, value in [('revision', 'wrong'), ('seconds', 0)]:
            got = copy.deepcopy(want); got['measurements'][0][key] = value
            with self.assertRaises(ValueError): m.verify(got, want)
        got = copy.deepcopy(want); got['measurements'].pop()
        with self.assertRaises(ValueError): m.verify(got, want)
    def test_correct_report_passes(self):
        for mode in ['lead', 'restore']:
            want = m.calculate(self.history, self.commits, mode)
            m.verify(copy.deepcopy(want), want)
if __name__ == '__main__': unittest.main()
