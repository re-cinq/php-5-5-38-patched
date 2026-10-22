<?php
$old_error_handler = set_error_handler(function () { return true; });
$old_exception_handler = set_exception_handler(function ($e) {});
$clean = is_null($old_error_handler) && is_null($old_exception_handler)
	&& isset($_GET['probe']['value']) && $_GET['probe']['value'] === 'clean';
echo $clean ? 'clean' : 'dirty', ' pid=', getmypid(), "\n";
