--TEST--
GHSA-w8hw-w9fx-j79w: memory_limit exhaustion inside handlers terminates without running further user code
--INI--
memory_limit=2M
--FILE--
<?php
register_shutdown_function(function () { echo "shutdown function ran\n"; });
set_error_handler(function ($no, $str) {
	echo "error handler: $str\n";
	$a = str_repeat('x', 4 * 1024 * 1024);
	echo "unreachable\n";
});
set_exception_handler(function ($e) { echo "exception handler ran\n"; });
echo $undefined;
echo "unreachable\n";
?>
--EXPECTF--
error handler: Undefined variable: undefined

Fatal error: Allowed memory size of %d bytes exhausted%s(tried to allocate %d bytes) in %s on line %d
