--TEST--
GHSA-w8hw-w9fx-j79w: smart_str size overflow during serialize() terminates without running user code
--SKIPIF--
<?php
if (PHP_INT_SIZE != 8) die("skip 64-bit only");
if (getenv("SKIP_SLOW_TESTS")) die("skip slow test");
?>
--INI--
memory_limit=-1
--FILE--
<?php
register_shutdown_function(function () { echo "shutdown function ran\n"; });
/* "s:N:"" plus the payload pushes the buffer past INT_MAX before it grows */
$s = str_repeat('x', 0x7fffffff - 100);
echo "built\n";
var_dump(strlen(serialize($s)));
echo "unreachable\n";
?>
--EXPECTF--
built

Fatal error: String size overflow in %s on line %d
