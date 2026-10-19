"""ST-13, S-15. Tests for scripts/check_personal_details.sh, the check that stops a real person's
email address or username from reaching the public repo.

Run from the repo root: python3 -m unittest discover -s tests/pipeline -v
Each test writes a small metadata folder, runs the script on it, and checks its exit code and
output. Every address here is made up; the "personal" ones are on domains nobody receives mail at
through this test, and the script must never print them.
"""

import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "check_personal_details.sh"

NETWORK = """<?xml version="1.0" encoding="UTF-8"?>
<Network xmlns="http://soap.sforce.com/2006/04/metadata">
    <emailSenderAddress>{sender}</emailSenderAddress>
    <emailSenderName>Lumenfield Customer Portal</emailSenderName>
</Network>
"""


class PersonalDetailsCheckTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.root = Path(self.folder.name)
        self.networks = self.root / "networks"
        self.networks.mkdir()

    def tearDown(self):
        self.folder.cleanup()

    def write_network(self, sender):
        path = self.networks / "Portal.network-meta.xml"
        path.write_text(NETWORK.format(sender=sender), encoding="utf-8")
        return path

    def run_check(self, *args):
        return subprocess.run(
            ["bash", str(SCRIPT), *args],
            capture_output=True,
            text=True,
            check=False,
        )

    def test_placeholders_on_example_domains_pass(self):
        self.write_network("portal@lumenfield.example")
        (self.root / "sites.xml").write_text(
            "<siteAdmin>steward.ci.lumenfield@example.com</siteAdmin>\n"
            "<owner>someone@test.example.com</owner>\n",
            encoding="utf-8",
        )
        result = self.run_check(str(self.root))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("No personal details found", result.stdout)

    def test_a_real_looking_address_fails_without_printing_it(self):
        path = self.write_network("jordan.rivers@mailbox.test")
        result = self.run_check(str(self.root))
        self.assertEqual(result.returncode, 1)
        self.assertIn(f"{path}:3", result.stdout, "Names the file and line")
        self.assertNotIn("jordan.rivers", result.stdout + result.stderr)
        self.assertNotIn("mailbox.test", result.stdout + result.stderr)

    def test_a_salesforce_style_username_fails(self):
        (self.root / "site.xml").write_text(
            "<siteAdmin>jrivers.4f2a9c@agentforce.com</siteAdmin>\n", encoding="utf-8"
        )
        result = self.run_check(str(self.root))
        self.assertEqual(result.returncode, 1)
        self.assertNotIn("jrivers", result.stdout + result.stderr)

    def test_a_lookalike_of_example_com_fails(self):
        self.write_network("portal@example.com.mailbox.test")
        self.assertEqual(self.run_check(str(self.root)).returncode, 1)
        self.write_network("portal@notexample.com")
        self.assertEqual(self.run_check(str(self.root)).returncode, 1)

    def test_each_place_is_listed_once(self):
        (self.root / "two.xml").write_text(
            "<a>first@mailbox.test</a> <b>second@mailbox.test</b>\n", encoding="utf-8"
        )
        result = self.run_check(str(self.root))
        places = [line for line in result.stdout.splitlines() if "two.xml" in line]
        self.assertEqual(len(places), 1, result.stdout)

    def test_code_that_imports_from_salesforce_modules_passes(self):
        lwc = self.root / "lwc" / "page"
        lwc.mkdir(parents=True)
        (lwc / "page.js").write_text(
            'import getData from "@salesforce/apex/Controller.getData";\n'
            'import basePath from "@salesforce/community/basePath";\n',
            encoding="utf-8",
        )
        result = self.run_check(str(self.root))
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_bad_usage_exits_2(self):
        self.assertEqual(self.run_check().returncode, 2)
        self.assertEqual(self.run_check(str(self.root / "missing")).returncode, 2)


if __name__ == "__main__":
    unittest.main()
