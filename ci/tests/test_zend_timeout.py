#!/usr/bin/env python3
import pathlib
import re
import subprocess
import tempfile
import textwrap
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
EXECUTOR = ROOT / "Zend" / "zend_execute_API.c"


def function_source(source, name):
    match = re.search(
        r"(?:static|ZEND_API) void %s\([^\n]+\)[^\n]*\n\{" % re.escape(name), source
    )
    if not match:
        raise AssertionError("function %s not found" % name)
    depth = 0
    for offset in range(match.end() - 1, len(source)):
        if source[offset] == "{":
            depth += 1
        elif source[offset] == "}":
            depth -= 1
            if depth == 0:
                return source[match.start():offset + 1]
    raise AssertionError("unterminated function %s" % name)


class ZendTimeoutTests(unittest.TestCase):
    def test_posix_handler_fetches_thread_state_only_after_hard_exit(self):
        source = EXECUTOR.read_text()
        handler = function_source(source, "zend_timeout")
        hard_exit = handler.index("_exit(124);")
        thread_fetch = handler.index("TSRMLS_FETCH();")

        self.assertLess(hard_exit, thread_fetch)
        zts_path = handler[handler.index("#ifdef ZTS"):handler.index("#else")]
        self.assertNotIn("EG(", zts_path)

    def test_timeout_message_uses_direct_signal_safe_writer(self):
        source = EXECUTOR.read_text()
        writer = function_source(source, "zend_timeout_write_stderr")
        harness = textwrap.dedent("""
            #include <errno.h>
            #include <stddef.h>
            #include <unistd.h>
            %s
            int main(void)
            {
                zend_timeout_write_stderr(-1);
                zend_timeout_write_stderr(1);
                zend_timeout_write_stderr(30);
                return 0;
            }
        """) % writer

        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            program = root / "timeout.c"
            executable = root / "timeout"
            program.write_text(harness)
            compile_result = subprocess.run(
                ["cc", "-std=c89", "-Wall", "-Wextra", str(program), "-o", str(executable)],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
            )
            self.assertEqual(0, compile_result.returncode, compile_result.stdout)
            result = subprocess.run(
                [str(executable)], stdout=subprocess.PIPE, stderr=subprocess.PIPE
            )

        self.assertEqual(0, result.returncode)
        self.assertEqual(
            b"\nFatal error: Maximum execution time exceeded (terminated)\n"
            b"\nFatal error: Maximum execution time of 1 second exceeded (terminated)\n"
            b"\nFatal error: Maximum execution time of 30 seconds exceeded (terminated)\n",
            result.stderr,
        )


if __name__ == "__main__":
    unittest.main()
