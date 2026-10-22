--TEST--
max_multipart_body_parts defaults to max_input_vars + max_file_uploads
--INI--
file_uploads=1
max_input_vars=1
max_file_uploads=1
--POST_RAW--
Content-Type: multipart/form-data; boundary=---------------------------20896060251896012921717172737
-----------------------------20896060251896012921717172737
Content-Disposition: form-data; name="a"

1
-----------------------------20896060251896012921717172737
Content-Disposition: form-data; name="f"; filename="file1.txt"
Content-Type: text/plain

file1
-----------------------------20896060251896012921717172737
Content-Disposition: form-data; name="c"

3
-----------------------------20896060251896012921717172737--
--FILE--
<?php
var_dump(ini_get("max_multipart_body_parts"));
var_dump($_POST);
var_dump($_FILES["f"]["name"], $_FILES["f"]["size"]);
?>
--EXPECTF--
Warning: Unknown: Multipart body parts limit exceeded 2. To increase the limit change max_multipart_body_parts in php.ini. in Unknown on line 0
string(2) "-1"
array(1) {
  ["a"]=>
  string(1) "1"
}
string(9) "file1.txt"
int(5)
