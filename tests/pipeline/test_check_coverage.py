"""ST-13. Tests for scripts/check_coverage.py, the 90% per-class coverage gate.

Run from the repo root: python3 -m unittest discover -s tests/pipeline -v
Each test writes a small source folder and a deployment result shaped like the one
`sf project deploy validate --json` returns, then checks the gate's exit code.
"""

import contextlib
import importlib.util
import io
import json
import os
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "check_coverage.py"
spec = importlib.util.spec_from_file_location("check_coverage", SCRIPT)
check_coverage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check_coverage)

SERVICE = "public with sharing class {name} {{\n  public static Integer run() {{ return 1; }}\n}}\n"
TEST_CLASS = "@IsTest\nprivate class {name} {{\n  @IsTest static void runs() {{ }}\n}}\n"


def coverage(name, total, missed, namespace=None):
    entry = {
        "id": "01p000000000001",
        "name": name,
        "numLocations": str(total),
        "numLocationsNotCovered": str(missed),
        "type": "Class",
    }
    if namespace:
        entry["namespace"] = namespace
    return entry


def deploy_result(code_coverage):
    run = {"numFailures": "0", "numTestsRun": "12", "totalTime": "900"}
    if code_coverage is not None:
        run["codeCoverage"] = code_coverage
    return {"status": 0, "result": {"status": "Succeeded", "details": {"runTestResult": run}}}


class CoverageGateTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.root = Path(self.folder.name)
        self.classes = self.root / "force-app" / "main" / "default" / "classes"
        self.classes.mkdir(parents=True)
        self.summary = self.root / "summary.md"
        os.environ["GITHUB_STEP_SUMMARY"] = str(self.summary)

    def tearDown(self):
        os.environ.pop("GITHUB_STEP_SUMMARY", None)
        self.folder.cleanup()

    def add_class(self, name, template=SERVICE):
        (self.classes / f"{name}.cls").write_text(template.format(name=name), encoding="utf-8")

    def run_gate(self, result, gate="90"):
        result_file = self.root / "validate.json"
        result_file.write_text(json.dumps(result), encoding="utf-8")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = check_coverage.main(
                ["check_coverage.py", str(result_file), str(self.root / "force-app"), gate]
            )
        return code, output.getvalue()

    def test_every_class_at_or_above_the_gate_passes(self):
        self.add_class("AccountSnapshotService")
        self.add_class("PolicySettings")

        code, output = self.run_gate(
            deploy_result(
                [coverage("AccountSnapshotService", 100, 10), coverage("PolicySettings", 40, 0)]
            )
        )

        self.assertEqual(0, code, output)
        self.assertIn("every class meets the gate", output)
        self.assertIn(
            "| AccountSnapshotService | 90.0% | 90 of 100 | Pass |", self.summary.read_text()
        )

    def test_one_class_below_the_gate_fails_and_is_named(self):
        self.add_class("AccountSnapshotService")
        self.add_class("PolicySettings")

        code, output = self.run_gate(
            deploy_result(
                [coverage("AccountSnapshotService", 1000, 101), coverage("PolicySettings", 40, 0)]
            )
        )

        self.assertEqual(1, code)
        self.assertIn("::error file=", output)
        self.assertIn("AccountSnapshotService is at 89.9%", output, "Rounded down, not up to 90.0%")

    def test_a_class_with_no_reported_coverage_counts_as_zero(self):
        self.add_class("AccountSnapshotService")
        self.add_class("DisputeIntakeService")

        code, output = self.run_gate(deploy_result([coverage("AccountSnapshotService", 50, 0)]))

        self.assertEqual(1, code)
        self.assertIn("reported no coverage for DisputeIntakeService", output)

    def test_a_single_entry_object_is_read_like_a_list(self):
        self.add_class("PolicySettings")

        code, output = self.run_gate(deploy_result(coverage("PolicySettings", 20, 1)))

        self.assertEqual(0, code, output)

    def test_no_test_results_fails_closed(self):
        self.add_class("PolicySettings")

        code, output = self.run_gate(
            {"status": 0, "result": {"status": "Succeeded", "details": {}}}
        )

        self.assertEqual(2, code)
        self.assertIn("has no test results", output)

    def test_test_classes_interfaces_and_enums_are_skipped(self):
        self.add_class("PolicySettings")
        self.add_class("PolicySettingsTest", TEST_CLASS)
        self.add_class(
            "StewardTestData",
            "/** Test data. */\n@IsTest\n@SuppressWarnings('PMD.ExcessiveParameterList')\n"
            "public class {name} {{ }}\n",
        )
        self.add_class("StewardAction", "public interface {name} {{ void run(); }}\n")
        self.add_class("Channel", "public enum {name} {{ CHAT, PORTAL }}\n")

        code, output = self.run_gate(deploy_result([coverage("PolicySettings", 20, 0)]))

        self.assertEqual(0, code, output)
        self.assertNotIn("PolicySettingsTest", output)
        self.assertNotIn("StewardTestData", output)
        self.assertIn("1 checked", output)

    def test_a_test_annotation_inside_a_comment_or_string_does_not_skip_the_class(self):
        self.add_class(
            "PolicySettings",
            "// @IsTest classes are skipped by the gate\n"
            "public with sharing class {name} {{\n"
            "  private static final String NOTE = '@IsTest';\n"
            "}}\n",
        )

        code, output = self.run_gate(deploy_result([]))

        self.assertEqual(1, code, "Gated, and with no coverage it fails")
        self.assertIn("reported no coverage for PolicySettings", output)

    def test_an_empty_exception_class_has_nothing_to_cover(self):
        self.add_class(
            "PaymentArrangementException", "public class {name} extends Exception {{}}\n"
        )
        self.add_class("PolicySettings")

        code, output = self.run_gate(deploy_result([coverage("PolicySettings", 20, 0)]))

        self.assertEqual(0, code, output)
        self.assertIn("No executable lines", output)

    def test_managed_package_code_with_the_same_name_is_ignored(self):
        self.add_class("PolicySettings")

        code, output = self.run_gate(
            deploy_result(
                [
                    coverage("PolicySettings", 20, 20, namespace="devedapp"),
                    coverage("PolicySettings", 20, 0),
                ]
            )
        )

        self.assertEqual(0, code, output)

    def test_triggers_are_gated_too(self):
        triggers = self.root / "force-app" / "main" / "default" / "triggers"
        triggers.mkdir(parents=True)
        (triggers / "PaymentReceivedTrigger.trigger").write_text(
            "trigger PaymentReceivedTrigger on Payment_Received__e (after insert) { }\n",
            encoding="utf-8",
        )

        code, output = self.run_gate(deploy_result([coverage("PaymentReceivedTrigger", 4, 3)]))

        self.assertEqual(1, code)
        self.assertIn("PaymentReceivedTrigger is at 25.0%", output)

    def test_a_folder_with_no_apex_passes_without_reading_the_result(self):
        code, output = self.run_gate({"not": "a deploy result"})

        self.assertEqual(0, code)
        self.assertIn("no coverage to check", output)

    def test_an_unreadable_result_fails(self):
        self.add_class("PolicySettings")
        (self.root / "validate.json").write_text("{ not json", encoding="utf-8")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = check_coverage.main(
                [
                    "check_coverage.py",
                    str(self.root / "validate.json"),
                    str(self.root / "force-app"),
                    "90",
                ]
            )

        self.assertEqual(2, code)
        self.assertIn("Couldn't read the deployment result", output.getvalue())


if __name__ == "__main__":
    unittest.main()
