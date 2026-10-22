--TEST--
GHSA-w8hw-w9fx-j79w: max_execution_time in a shutdown function terminates without running the next one
--SKIPIF--
<?php
if (getenv("SKIP_SLOW_TESTS")) die("skip slow test");
if (substr(PHP_OS, 0, 3) == "WIN") die("skip not for Windows: the timeout is handled between opcodes there");
?>
--FILE--
<?php
register_shutdown_function(function () {
	echo "first shutdown function\n";
	set_time_limit(1);
	while (true) {}
});
register_shutdown_function(function () { echo "second shutdown function ran\n"; });
echo "end of script\n";
?>
--EXPECTF--
end of script
first shutdown function

Fatal error: Maximum execution time of 1 second exceeded (terminated) in %s on line %d
