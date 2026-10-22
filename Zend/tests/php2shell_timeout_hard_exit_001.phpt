--TEST--
GHSA-w8hw-w9fx-j79w: max_execution_time terminates without running user code
--SKIPIF--
<?php
if (getenv("SKIP_SLOW_TESTS")) die("skip slow test");
if (substr(PHP_OS, 0, 3) == "WIN") die("skip not for Windows: the timeout is handled between opcodes there");
?>
--FILE--
<?php
class D { function __destruct() { echo "destructor ran\n"; } }
$d = new D;
register_shutdown_function(function () { echo "shutdown function ran\n"; });
set_error_handler(function () { echo "error handler ran\n"; });
ob_start(function ($buf) { return "output handler ran\n" . $buf; });
echo "buffered\n";
set_time_limit(1);
while (true) {
	$a = array();
	for ($i = 0; $i < 100; $i++) { $a["k$i"] = str_repeat('x', $i); }
}
?>
--EXPECTF--
Fatal error: Maximum execution time of 1 second exceeded (terminated)
