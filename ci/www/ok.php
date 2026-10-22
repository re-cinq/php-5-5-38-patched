<?php
$x = array();
for ($i = 0; $i < 1000; $i++) { $x["k$i"] = $i; }
echo array_sum($x) === 499500 ? "ok" : "bad", " ", isset($_GET['n']) ? $_GET['n'] : '-', "\n";
