<?php
/* Bail out while request cleanup is running. The next request must see clean
 * executor state even when the same worker handles it. */
class CleanupBailout {
	public function __destruct() {
		/* The marker proves this destructor, rather than merely the script,
		 * reached the cleanup bailout in the worker whose PID is recorded. */
		file_put_contents(__DIR__ . '/markers/fatal-pid', getmypid());
		undefined_function_called_during_cleanup();
	}
}

set_error_handler(function () { return false; });
set_exception_handler(function ($e) { echo "exception handler\n"; });
session_save_path(__DIR__ . '/markers');
session_start();
$_SESSION['data'] = str_repeat('a', 100);
$GLOBALS['cleanup_bailout'] = new CleanupBailout();
$GLOBALS['object_in_use'] = new ArrayObject(array(1, 2, 3));
try { throw new Exception("caught"); } catch (Exception $e) {}
