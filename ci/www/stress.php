<?php
/* Stress test for max_execution_time: the timer fires at an arbitrary point
 * while the heap and hash tables are being updated. Unpatched 5.5 bails out
 * from the signal handler and runs the shutdown function on that state, which
 * corrupts the heap in a sizeable share of requests. The patch terminates the
 * worker instead, so the shutdown function never runs. */
set_time_limit(1);
$GLOBALS['check'] = array();
for ($i = 0; $i < 2000; $i++) { $GLOBALS['check']["k$i"] = str_repeat('v', $i % 97); }
register_shutdown_function(function () {
	$t = array();
	foreach ($GLOBALS['check'] as $k => $v) { $t[] = $k . $v; }
	file_put_contents(__DIR__ . '/markers/stress-' . getmypid() . '-' . mt_rand(), count($t));
});
while (true) {
	$a = array();
	for ($i = 0; $i < 300; $i++) { $a["x$i"] = str_repeat('a', $i) . $i; $a[] = array($i, "$i"); }
	unset($a[array_rand($a)]);
	$GLOBALS['check']['k' . mt_rand(0, 1999)] = '';
	unset($GLOBALS['check']['k' . mt_rand(0, 1999)]);
}
