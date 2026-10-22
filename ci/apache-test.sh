#!/usr/bin/env bash
# Apache 2.4 prefork + mod_php integration test: a request that exceeds
# memory_limit or max_execution_time must terminate only its child, without
# running user code, and Apache must keep serving requests. Requests that end
# in a regular fatal error must not affect later requests served by the same
# children.
# usage: ci/apache-test.sh <php-src-dir built with --with-apxs2>
set -uo pipefail
SRC=$(cd "$1" && pwd)
CI_DIR=$(cd "$(dirname "$0")" && pwd)
. "$CI_DIR/lib.sh"
FAILED=0
prepare_www
RUN=$(mktemp -d)
LOG=$RUN/error.log
PORT=8085
MODULES=$(apxs -q LIBEXECDIR)

cat > "$RUN/httpd.conf" <<CONF
ServerRoot "$RUN"
ServerName localhost
Listen 127.0.0.1:$PORT
PidFile "$RUN/httpd.pid"
DefaultRuntimeDir "$RUN"
ErrorLog "$LOG"
LogLevel notice
LoadModule mpm_prefork_module $MODULES/mod_mpm_prefork.so
LoadModule authz_core_module $MODULES/mod_authz_core.so
LoadModule php5_module $SRC/libs/libphp5.so
StartServers 2
MinSpareServers 2
MaxSpareServers 4
MaxRequestWorkers 4
PHPIniDir "$WWW"
DocumentRoot "$WWW"
<Directory "$WWW">
	Require all granted
</Directory>
<FilesMatch "\.php$">
	SetHandler application/x-httpd-php
</FilesMatch>
CONF

/usr/sbin/apache2 -f "$RUN/httpd.conf" -k start || { cat "$LOG"; exit 1; }
trap '/usr/sbin/apache2 -f "$RUN/httpd.conf" -k stop; sleep 1; echo "----- apache error log"; cat "$LOG"' EXIT
for _ in $(seq 1 50); do curl -s -o /dev/null "http://127.0.0.1:$PORT/ok.php" && break; sleep 0.2; done

request() { curl -s -m 30 "http://127.0.0.1:$PORT/$1"; }

check_ok "baseline request" "$(request 'ok.php?n=0')" 0

for i in $(seq 1 20); do
	request fatal.php > /dev/null
	check_ok "request $i after a fatal error" "$(request "ok.php?n=$i")" "$i"
done

body=$(request 'oom.php?id=apache'); rc=$?
case "$body" in *unreachable*) fail "oom: script continued after exceeding memory_limit";; esac
[ $rc -eq 52 ] && pass "oom: child terminated (empty reply)" || fail "oom: expected an empty reply (curl exit 52), got curl exit $rc"
sleep 1
check_no_marker oom-apache
grep -q 'Allowed memory size of [0-9]* bytes exhausted' "$LOG" && pass "oom: fatal error logged via child stderr" || fail "oom: fatal error not found in the error log"
for i in 1 2 3 4 5 6; do check_ok "request $i after OOM" "$(request "ok.php?n=$i")" "$i"; done

request 'timeout.php?id=apache' > /dev/null; rc=$?
[ $rc -eq 52 ] && pass "timeout: child terminated (empty reply)" || fail "timeout: expected an empty reply (curl exit 52), got curl exit $rc"
sleep 1
check_no_marker timeout-apache
grep -q 'Maximum execution time of 1 second exceeded (terminated)' "$LOG" && pass "timeout: fatal error logged via child stderr" || fail "timeout: fatal error not found in the error log"
for i in 1 2 3 4 5 6; do check_ok "request $i after timeout" "$(request "ok.php?n=$i")" "$i"; done

if grep -qE 'exit signal|Segmentation fault|zend_mm_heap corrupted' "$LOG"; then
	fail "a child crashed (see error log)"
else
	pass "no child crashed"
fi
exit $FAILED
