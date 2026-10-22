<?php
/* Exceeds memory_limit. The worker must terminate without running any user code. */
$marker = __DIR__ . '/markers/oom-' . $_GET['id'];
register_shutdown_function(function () use ($marker) { file_put_contents($marker, "shutdown ran\n"); });
$a = str_repeat('x', 256 * 1024 * 1024);
echo "unreachable\n";
