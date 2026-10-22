--TEST--
GHSA-w8hw-w9fx-j79w: the max_execution_time message is written to stderr regardless of display_errors
--SKIPIF--
<?php
if (getenv("SKIP_SLOW_TESTS")) die("skip slow test");
if (substr(PHP_OS, 0, 3) == "WIN") die("skip not for Windows: the timeout is handled between opcodes there");
?>
--INI--
display_errors=0
--FILE--
<?php
register_shutdown_function(function () { echo "shutdown function ran\n"; });
echo "Start\n";
set_time_limit(1);
for (;;) {}
?>
--EXPECTF--
Start

Fatal error: Maximum execution time of 1 second exceeded (terminated) in %s on line %d
