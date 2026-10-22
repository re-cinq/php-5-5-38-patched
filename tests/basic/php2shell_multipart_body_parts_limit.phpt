--TEST--
max_multipart_body_parts limits the number of multipart body parts
--INI--
file_uploads=1
max_multipart_body_parts=2
--POST_RAW--
Content-Type: multipart/form-data; boundary=---------------------------20896060251896012921717172737
-----------------------------20896060251896012921717172737
Content-Disposition: form-data; name="a"

1
-----------------------------20896060251896012921717172737
Content-Disposition: form-data; name="b"

2
-----------------------------20896060251896012921717172737
Content-Disposition: form-data; name="c"

3
-----------------------------20896060251896012921717172737--
--FILE--
<?php
var_dump($_POST);
?>
--EXPECTF--
Warning: Unknown: Multipart body parts limit exceeded 2. To increase the limit change max_multipart_body_parts in php.ini. in Unknown on line 0
array(2) {
  ["a"]=>
  string(1) "1"
  ["b"]=>
  string(1) "2"
}
