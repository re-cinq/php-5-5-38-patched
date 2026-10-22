--TEST--
GHSA-w8hw-w9fx-j79w: Balloc() list boundary in unserialize() terminates without running user code
--FILE--
<?php
class D { function __destruct() { echo "destructor ran\n"; } }
$d = new D;
register_shutdown_function(function () { echo "shutdown function ran\n"; });
set_error_handler(function () { echo "error handler ran\n"; });
var_dump(unserialize('a:2:{i:0;s:3:"foo";i:1;d:0.' . str_repeat('1', 300000) . ';}'));
echo "unreachable\n";
?>
--EXPECTF--
Fatal error: Balloc() allocation exceeds list boundary in %s on line %d
