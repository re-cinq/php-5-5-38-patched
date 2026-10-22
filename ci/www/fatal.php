<?php
/* Ends in a regular fatal error with request state in use: the next
 * request handled by the same worker must not be affected. */
set_error_handler(function () { return false; });
set_exception_handler(function ($e) { echo "exception handler\n"; });
session_save_path(__DIR__ . '/markers');
session_start();
$_SESSION['data'] = str_repeat('a', 100);
$o = new ArrayObject(array(1, 2, 3));
try { throw new Exception("caught"); } catch (Exception $e) {}
undefined_function_call();
