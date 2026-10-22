#!/usr/bin/env python3
"""Compare run-tests.php results of the patched tree against pristine PHP 5.5.38.

Fails if
  - a php2shell_* regression test does not PASS on the patched tree,
  - a php2shell_* test that targets the vulnerable behaviour does not FAIL on
    pristine 5.5.38 (i.e. it would not detect PHP2Shell),
  - a test that passes on pristine fails on the patched tree, after re-running
    it to rule out flaky (network/timing dependent) tests,
  - the patched tree introduces an XFAIL outside the explicit upload-progress
    allowlist,
  - the patched tree introduces a SKIP outside the explicit timeout-behaviour
    allowlist, or reports WARN where pristine passes,
  - either suite did not run to completion, or a test that ran on pristine did
    not run on the patched tree.
"""
import os
import re
import subprocess
import sys

# Guard behaviour that 5.5.38 already had; they pass on both trees.
REGRESSION_ONLY = {
    "tests/basic/php2shell_multipart_headers.phpt",
    "Zend/tests/php2shell_oom_hard_exit_003.phpt",
}
EXPECTED_PATCH_XFAILS = {
    "ext/session/tests/rfc1867.phpt",
    "ext/session/tests/rfc1867_inter.phpt",
    "ext/session/tests/rfc1867_sid_cookie.phpt",
    "ext/session/tests/rfc1867_sid_get.phpt",
    "ext/session/tests/rfc1867_sid_get_2.phpt",
    "ext/session/tests/rfc1867_sid_invalid.phpt",
    "ext/session/tests/rfc1867_sid_only_cookie.phpt",
    "ext/session/tests/rfc1867_sid_post.phpt",
}
EXPECTED_PATCH_SKIPS = {
    "tests/func/005a.phpt",
    "tests/lang/045.phpt",
}
RESULT_RE = re.compile(r"\b(PASS|FAIL|SKIP|XFAIL|BORK|LEAK|WARN)\s.*?\[([^\]\s]+\.phpt)\]")


def completed(log):
    with open(log, errors="replace") as f:
        text = f.read().replace("\r", "\n")
    # run-tests.php prints these only after the last test
    return (re.search(r"^Number of tests\s*:\s*\d+", text, re.M) is not None
            and re.search(r"^Time taken\s*:\s*\d+ seconds", text, re.M) is not None)


def parse(log):
    with open(log, errors="replace") as f:
        text = f.read().replace("\r", "\n")
    results = {}
    for m in RESULT_RE.finditer(text):
        results[m.group(2)] = m.group(1)
    return results


def rerun(src, test):
    out = os.path.abspath(os.path.join(src, "rerun.log"))
    subprocess.run([os.path.join(os.path.dirname(os.path.abspath(__file__)), "run-suite.sh"), src, out, test], check=True)
    return parse(out).get(test)


def main():
    patched_src, patched_log, pristine_src, pristine_log = sys.argv[1:5]
    patched, pristine = parse(patched_log), parse(pristine_log)
    if not patched or not pristine:
        print("::error::no test results parsed")
        return 1
    errors = []

    for name, log in (("patched", patched_log), ("pristine", pristine_log)):
        if not completed(log):
            errors.append(f"{name} test suite did not run to completion (no result summary in {log})")
    missing = sorted(set(pristine) - set(patched))
    for t in missing:
        errors.append(f"{t}: ran on pristine 5.5.38 but not on the patched tree")

    new_xfails = sorted(t for t, result in patched.items()
                        if result == "XFAIL" and pristine.get(t) != "XFAIL")
    for t in new_xfails:
        if t not in EXPECTED_PATCH_XFAILS:
            errors.append(f"{t}: new XFAIL on patched tree (not in the explicit allowlist)")

    new_skips = sorted(t for t, result in patched.items()
                       if result == "SKIP" and pristine.get(t) != "SKIP")
    for t in new_skips:
        if t not in EXPECTED_PATCH_SKIPS:
            errors.append(f"{t}: new SKIP on patched tree (not in the explicit allowlist)")

    for t in sorted(patched):
        if patched[t] == "WARN" and pristine.get(t) in ("PASS", "SKIP"):
            errors.append(f"{t}: WARN on patched tree, {pristine[t]} on pristine 5.5.38")

    php2shell = sorted(t for t in patched if "php2shell_" in t)
    if not php2shell:
        errors.append("no php2shell_* tests were run")
    for t in php2shell:
        if patched[t] != "PASS":
            errors.append(f"{t}: {patched[t]} on patched tree, expected PASS")
        if t not in REGRESSION_ONLY and pristine.get(t) != "FAIL":
            errors.append(f"{t}: {pristine.get(t)} on pristine 5.5.38, expected FAIL (test does not detect the vulnerability)")

    flaky = []
    for t in sorted(patched):
        if patched[t] in ("FAIL", "BORK", "LEAK") and pristine.get(t) in ("PASS", "SKIP") and "php2shell_" not in t:
            results = [rerun(patched_src, t) for _ in range(2)]
            if "PASS" in results:
                flaky.append(t)
            else:
                errors.append(f"{t}: {patched[t]} on patched tree (re-run: {results}), {pristine[t]} on pristine 5.5.38")

    count = lambda r, s: sum(1 for v in r.values() if v == s)
    for name, r in (("patched", patched), ("pristine", pristine)):
        print(f"{name}: {len(r)} tests, {count(r, 'PASS')} pass, {count(r, 'FAIL')} fail, "
              f"{count(r, 'SKIP')} skip, {count(r, 'XFAIL')} xfail")
    print(f"php2shell regression tests: {len(php2shell)}")
    for t in flaky:
        print(f"::warning::{t} failed once on the patched tree but passed on re-run")
    for e in errors:
        print(f"::error::{e}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
