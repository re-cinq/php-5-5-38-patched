#!/usr/bin/env bash
# Apache 2.4 prefork + mod_php integration test: a request that exceeds
# memory_limit or max_execution_time must terminate only its child, without
# running user code, and Apache must keep serving requests. A bailout during
# request cleanup must leave clean state for the next request in the same child.
# usage: ci/apache-test.sh <php-src-dir built with --with-apxs2>
set -uo pipefail
SRC=$(cd "$1" && pwd)
CI_DIR=$(cd "$(dirname "$0")" && pwd)
. "$CI_DIR/lib.sh"
FAILED=0
prepare_www apache
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
StartServers 1
MinSpareServers 1
MaxSpareServers 1
MaxRequestWorkers 1
PHPIniDir "$WWW"
DocumentRoot "$WWW"
<Directory "$WWW">
	Require all granted
	AllowOverride Options
</Directory>
<FilesMatch "\.php$">
	SetHandler application/x-httpd-php
</FilesMatch>
# Shipped hardening (config/php2shell)
Include "$CONFIG_DIR/apache-mod_php.conf"
# Keep the production limit locked, but shorten it for timeout stress tests.
php_admin_value max_execution_time 1
CONF

/usr/sbin/apache2 -f "$RUN/httpd.conf" -t || { echo "::error::Apache configuration test failed"; exit 1; }
pass "Apache configuration test"

/usr/sbin/apache2 -f "$RUN/httpd.conf" -k start || { cat "$LOG"; exit 1; }
trap '/usr/sbin/apache2 -f "$RUN/httpd.conf" -k stop; sleep 1; echo "----- apache error log"; cat "$LOG"' EXIT
for _ in $(seq 1 50); do curl -s -o /dev/null "http://127.0.0.1:$PORT/ok.php" && break; sleep 0.2; done

request() {
	local target=$1
	[ -n "${2:-}" ] && target="$target?$2"
	curl -s -m 30 "http://127.0.0.1:$PORT/$target"
}

check_ok "baseline request" "$(request 'ok.php?n=0')" 0

check_settings "$(request settings.php)" 1
curl -s -D - -o /dev/null "http://127.0.0.1:$PORT/ok.php" | grep -qi '^X-Powered-By' && fail "X-Powered-By header exposed" || pass "no X-Powered-By header"

# LimitRequestBody rejects a body above 8M before PHP parses it
head -c $((9 * 1024 * 1024)) /dev/zero | tr '\0' 'a' > "$RUN/big-body"
status=$(curl -s -m 60 -o /dev/null -w '%{http_code}' -H 'Content-Type: application/x-www-form-urlencoded' \
	--data-binary @"$RUN/big-body" "http://127.0.0.1:$PORT/settings.php")
[ "$status" = 413 ] && pass "body above LimitRequestBody rejected with 413" || fail "body above LimitRequestBody: expected HTTP 413, got $status"
check_ok "request after oversized POST" "$(request 'ok.php?n=0')" 0

for i in $(seq 1 20); do
	check_cleanup_reuse "cleanup bailout $i"
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

# Timeout stress (see ci/www/stress.php)
STRESS_N=30
for i in $(seq 1 $STRESS_N); do request stress.php > /dev/null; done
sleep 1
check_stress "$LOG" $STRESS_N
for i in 1 2 3 4; do check_ok "request $i after stress" "$(request "ok.php?n=$i")" "$i"; done

if grep -qE 'exit signal|Segmentation fault|zend_mm_heap corrupted' "$LOG"; then
	fail "a child crashed (see error log)"
else
	pass "no child crashed"
fi
exit $FAILED
