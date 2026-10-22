<?php
foreach (array('session.upload_progress.enabled', 'max_input_nesting_level', 'max_input_time',
		'memory_limit', 'post_max_size', 'expose_php', 'display_errors') as $k) {
	echo $k, '=', ini_get($k), "\n";
}
echo 'post_vars=', count($_POST), "\n";
