#!/usr/bin/env python3
import pathlib
import re
import subprocess
import tempfile
import textwrap
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
ALLOCATOR = ROOT / "Zend" / "zend_alloc.c"


def function_source(source, name):
    match = re.search(r"static void %s\([^\n]+\)\n\{" % re.escape(name), source)
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


class ZendMmPanicTests(unittest.TestCase):
    def test_message_survives_buffered_stderr_and_immediate_exit(self):
        source = ALLOCATOR.read_text()
        panic = function_source(source, "zend_mm_panic")
        writer = function_source(source, "zend_mm_write_stderr")
        harness = textwrap.dedent("""
            #include <stddef.h>
            #include <stdio.h>
            #include <string.h>
            #include <unistd.h>
            #define ZEND_DEBUG 0
            %s
            %s
            int main(void)
            {
                char buffer[4096];
                setvbuf(stderr, buffer, _IOFBF, sizeof(buffer));
                zend_mm_panic("zend_mm_heap corrupted");
            }
        """) % (writer, panic)

        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            program = root / "panic.c"
            executable = root / "panic"
            program.write_text(harness)
            compile_result = subprocess.run(
                ["cc", "-std=c89", "-Wall", "-Wextra", "-Wno-unused-function",
                 str(program), "-o", str(executable)],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
            )
            self.assertEqual(0, compile_result.returncode, compile_result.stdout)
            result = subprocess.run(
                [str(executable)], stdout=subprocess.PIPE, stderr=subprocess.PIPE
            )

        self.assertEqual(1, result.returncode)
        self.assertEqual(b"zend_mm_heap corrupted\n", result.stderr)


if __name__ == "__main__":
    unittest.main()
