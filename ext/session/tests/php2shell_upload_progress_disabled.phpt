--TEST--
GHSA-w8hw-w9fx-j79w / GHSA-6wmf-4rv5-p3rp: session upload progress is disabled
--INI--
file_uploads=1
error_reporting=E_ALL&~E_NOTICE
upload_max_filesize=1024
session.save_path=
session.name=PHPSESSID
session.use_strict_mode=0
session.use_cookies=1
session.use_only_cookies=0
session.upload_progress.enabled=1
session.upload_progress.cleanup=0
session.upload_progress.prefix=upload_progress_
session.upload_progress.name=PHP_SESSION_UPLOAD_PROGRESS
session.upload_progress.freq=1%
session.upload_progress.min_freq=0.000000001
--SKIPIF--
<?php include('skipif.inc'); ?>
--COOKIE--
PHPSESSID=php2shell-upload-progress
--POST_RAW--
Content-Type: multipart/form-data; boundary=---------------------------20896060251896012921717172737
-----------------------------20896060251896012921717172737
Content-Disposition: form-data; name="PHP_SESSION_UPLOAD_PROGRESS"

php2shell_upload_progress_disabled.php
-----------------------------20896060251896012921717172737
Content-Disposition: form-data; name="file1"; filename="file1.txt"

1
-----------------------------20896060251896012921717172737--
--FILE--
<?php
ob_start();
/* The upload progress handler would have started the session while parsing
 * the request body, before RINIT */
var_dump(session_status() === PHP_SESSION_NONE);
var_dump(ini_get("session.upload_progress.enabled"));
var_dump($_FILES["file1"]["name"], $_FILES["file1"]["error"]);
session_start();
var_dump(session_id());
var_dump(isset($_SESSION["upload_progress_" . basename(__FILE__)]));
var_dump($_SESSION);
session_destroy();
?>
--EXPECT--
bool(true)
string(1) "1"
string(9) "file1.txt"
int(0)
string(25) "php2shell-upload-progress"
bool(false)
array(0) {
}
