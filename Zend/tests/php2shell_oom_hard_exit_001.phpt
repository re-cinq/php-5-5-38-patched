--TEST--
GHSA-w8hw-w9fx-j79w: memory_limit exhaustion terminates without running user code
--INI--
memory_limit=2M
--FILE--
<?php
class D { function __destruct() { echo "destructor ran\n"; } }
$d = new D;
register_shutdown_function(function () { echo "shutdown function ran\n"; });
ob_start(function ($buf) { return "output handler ran\n" . $buf; });
echo "buffered\n";
$a = str_repeat('x', 4 * 1024 * 1024);
echo "unreachable\n";
?>
--EXPECTF--
Fatal error: Allowed memory size of %d bytes exhausted%s(tried to allocate %d bytes) in %s on line %d
