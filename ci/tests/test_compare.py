#!/usr/bin/env python3
import pathlib
import subprocess
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
COMPARE = ROOT / "ci" / "compare.py"
REGRESSION = "tests/basic/php2shell_multipart_headers.phpt"
EXPECTED_XFAILS = (
    "ext/session/tests/rfc1867.phpt",
    "ext/session/tests/rfc1867_inter.phpt",
    "ext/session/tests/rfc1867_sid_cookie.phpt",
    "ext/session/tests/rfc1867_sid_get.phpt",
    "ext/session/tests/rfc1867_sid_get_2.phpt",
    "ext/session/tests/rfc1867_sid_invalid.phpt",
    "ext/session/tests/rfc1867_sid_only_cookie.phpt",
    "ext/session/tests/rfc1867_sid_post.phpt",
)


def log_text(results):
    lines = ["%s result [%s]" % (status, test) for test, status in results]
    lines.extend(("Number of tests : %d" % len(results), "Time taken : 1 seconds"))
    return "\n".join(lines) + "\n"


class CompareCliTests(unittest.TestCase):
    def run_compare(self, patched_results, pristine_results):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            patched_src = root / "patched"
            pristine_src = root / "pristine"
            patched_src.mkdir()
            pristine_src.mkdir()
            patched_log = root / "patched.log"
            pristine_log = root / "pristine.log"
            patched_log.write_text(log_text(patched_results))
            pristine_log.write_text(log_text(pristine_results))
            return subprocess.run(
                [sys.executable, str(COMPARE), str(patched_src), str(patched_log),
                 str(pristine_src), str(pristine_log)],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
            )

    def test_rejects_unexpected_new_xfail(self):
        patched = [(REGRESSION, "PASS"), ("tests/example.phpt", "XFAIL")]
        pristine = [(REGRESSION, "PASS"), ("tests/example.phpt", "PASS")]

        result = self.run_compare(patched, pristine)

        self.assertEqual(1, result.returncode, result.stdout)
        self.assertIn("tests/example.phpt: new XFAIL on patched tree", result.stdout)

    def test_accepts_only_the_expected_upload_progress_xfails(self):
        patched = [(REGRESSION, "PASS")] + [(test, "XFAIL") for test in EXPECTED_XFAILS]
        pristine = [(REGRESSION, "PASS")] + [(test, "PASS") for test in EXPECTED_XFAILS]

        result = self.run_compare(patched, pristine)

        self.assertEqual(0, result.returncode, result.stdout)


if __name__ == "__main__":
    unittest.main()
