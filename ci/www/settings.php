<?php
foreach (array('session.upload_progress.enabled', 'max_input_nesting_level', 'max_input_time',
		'max_input_vars', 'max_multipart_body_parts', 'max_file_uploads',
		'memory_limit', 'post_max_size', 'upload_max_filesize', 'expose_php', 'display_errors') as $k) {
	echo $k, '=', ini_get($k), "\n";
}
echo 'override_probe=', ini_get('precision'), "\n";
echo 'post_vars=', count($_POST), "\n";
