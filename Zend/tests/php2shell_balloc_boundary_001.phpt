--TEST--
GHSA-w8hw-w9fx-j79w: Balloc() list boundary in string to float conversion terminates without running user code
--FILE--
<?php
class D { function __destruct() { echo "destructor ran\n"; } }
$d = new D;
register_shutdown_function(function () { echo "shutdown function ran\n"; });
ob_start(function ($buf) { return "output handler ran\n" . $buf; });
echo "buffered\n";
$s = '0.' . str_repeat('1', 300000);
var_dump((float) $s);
echo "unreachable\n";
?>
--EXPECTF--
Fatal error: Balloc() allocation exceeds list boundary in %s on line %d
