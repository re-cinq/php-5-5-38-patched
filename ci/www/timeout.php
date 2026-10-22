<?php
/* Exceeds max_execution_time. The worker must terminate without running any user code. */
$marker = __DIR__ . '/markers/timeout-' . $_GET['id'];
register_shutdown_function(function () use ($marker) { file_put_contents($marker, "shutdown ran\n"); });
set_time_limit(1);
while (true) {
	$a = array();
	for ($i = 0; $i < 100; $i++) { $a["k$i"] = str_repeat('x', $i); }
}
