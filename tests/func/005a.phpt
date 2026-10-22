--TEST--
Testing register_shutdown_function() with timeout. (Bug: #21513)
--SKIPIF--
<?php
if (getenv("SKIP_SLOW_TESTS")) die("skip slow test");
/* Elsewhere the process is terminated on timeout, see php2shell_timeout_hard_exit_*.phpt */
if (substr(PHP_OS, 0, 3) != "WIN") die("skip Windows only: shutdown functions no longer run after a timeout");
?>
--FILE--
<?php

ini_set('display_errors', 0);
    
echo "Start\n";

function boo()
{
	echo "Shutdown\n";
}

register_shutdown_function("boo");

/* not necessary, just to show the error sooner */
set_time_limit(1); 

/* infinite loop to simulate long processing */
for (;;) {}

echo "End\n";

?>
--EXPECT--
Start
Shutdown
