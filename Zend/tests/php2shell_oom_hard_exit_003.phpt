--TEST--
GHSA-w8hw-w9fx-j79w: memory_limit exhaustion in a destructor during shutdown terminates the process
--INI--
memory_limit=2M
--FILE--
<?php
class D {
	function __destruct() {
		echo "destructor\n";
		$a = str_repeat('x', 4 * 1024 * 1024);
		echo "unreachable\n";
	}
}
class E { function __destruct() { echo "second destructor ran\n"; } }
/* Globals are destroyed in reverse order: $d first, then $e */
$e = new E;
$d = new D;
register_shutdown_function(function () { echo "shutdown function\n"; });
echo "end of script\n";
?>
--EXPECTF--
end of script
shutdown function
destructor

Fatal error: Allowed memory size of %d bytes exhausted%s(tried to allocate %d bytes) in %s on line %d
