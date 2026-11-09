#!/usr/bin/env python3
"""Exercise course discovery failures that would otherwise omit lab coverage."""
import copy
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

import yaml

CHECKER = Path(__file__).with_name("check-course-structure.py")
MODULE = "sections/section-010/module-10"
LAB = MODULE + "/labs/lab-01"
LESSON = MODULE + "/course-010-discovery.md"


class CourseStructureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        script = self.root / "scripts/ci/check-course-structure.py"
        script.parent.mkdir(parents=True)
        shutil.copyfile(CHECKER, script)
        self.script = script
        self.write(LESSON, f"# Discovery\n\n<!-- astrona:playground:renew -->\n\n```sh\ninspect\n```\n\n## Your mission: Discovery\n\n{LAB}\n")
        self.write(LAB + "/question.md", "# Question\n\n1. Inspect the source.\n2. Repair discovery.\n3. Verify the targets.\n")
        self.write(LAB + "/testing/verify-start.sh", "#!/bin/sh\nexit 0\n")
        self.write(LAB + "/solution/apply.sh", "#!/bin/sh\nexit 0\n")
        self.write(LAB + "/validation/check.sh", "#!/bin/sh\nexit 0\n")
        self.config = {
            "metadata": {"name": "discovery", "docs": {"question": "question.md"}},
            "testing": {"init": [
                {"type": "file", "source": "testing/verify-start.sh"},
                {"type": "file", "source": "solution/apply.sh"}]},
            "validation": {"scripts": [{"type": "file", "source": "validation/check.sh"}]},
        }
        self.write_yaml(LAB + "/config.yaml", self.config)
        self.content = [
            {"type": "reading", "path": LESSON},
            {"type": "reading", "path": LAB + "/question.md"},
            {"type": "lab", "path": LAB},
        ]
        self.save_outline()

    def write(self, path, text):
        file = self.root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(text)

    def write_yaml(self, path, value):
        self.write(path, yaml.safe_dump(value))

    def save_outline(self):
        self.write_yaml("astrona.yaml", {"modules": [{"content": self.content}]})

    def run_check(self):
        return subprocess.run([sys.executable, str(self.script)], text=True, capture_output=True)

    def assert_rejected(self, reason):
        result = self.run_check()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(reason, result.stdout)

    def test_complete_lab_passes(self):
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_unregistered_lab_fails(self):
        self.content.pop()
        self.save_outline()
        self.assert_rejected("Unregistered lab")

    def test_duplicate_registration_fails(self):
        self.content.extend(copy.deepcopy(self.content))
        self.save_outline()
        self.assert_rejected("Duplicate lab registration")

    def test_wrong_preparation_order_fails(self):
        self.content[0]["path"] = MODULE + "/course-000.md"
        self.write(MODULE + "/course-000.md", "# Start\n\n<!-- astrona:playground -->\n")
        self.save_outline()
        self.assert_rejected("preparation lesson")

    def test_too_many_tasks_fail(self):
        self.write(LAB + "/question.md", "\n".join(f"{n}. Task" for n in range(1, 7)))
        self.assert_rejected("expected 3–5 tasks")

    def test_missing_reference_solution_fails(self):
        (self.root / LAB / "solution/apply.sh").unlink()
        self.assert_rejected("missing source solution/apply.sh")

    def test_start_check_must_precede_solution(self):
        self.config["testing"]["init"].reverse()
        self.write_yaml(LAB + "/config.yaml", self.config)
        self.assert_rejected("verify the starting state before the solution")

    def test_runtime_collision_fails(self):
        playground = MODULE + "/playground"
        self.write_yaml(playground + "/config.yaml", {"metadata": {"name": "discovery"}})
        self.assert_rejected("also used by")


if __name__ == "__main__":
    unittest.main()
