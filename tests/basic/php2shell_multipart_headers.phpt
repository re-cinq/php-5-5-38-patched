--TEST--
Multipart parser keeps only Content-Disposition/Content-Type headers and ignores duplicates
--INI--
file_uploads=1
--POST_RAW--
Content-Type: multipart/form-data; boundary=---------------------------20896060251896012921717172737
-----------------------------20896060251896012921717172737
X-Ignored: foo
Content-Disposition: form-data; name="first"
Content-Disposition: form-data; name="second"
X-Ignored-Too: bar
 continuation of an ignored header

value
-----------------------------20896060251896012921717172737
Content-Disposition: form-data; name="f"; filename="file1.txt"
Content-Type: text/plain
Content-Type: application/x-second
Content-Transfer-Encoding: binary

file1
-----------------------------20896060251896012921717172737--
--FILE--
<?php
var_dump($_POST);
var_dump($_FILES["f"]["name"], $_FILES["f"]["type"], $_FILES["f"]["size"], $_FILES["f"]["error"]);
?>
--EXPECT--
array(1) {
  ["first"]=>
  string(5) "value"
}
string(9) "file1.txt"
string(10) "text/plain"
int(5)
int(0)
