#!/usr/bin/env bash
# PHP-FPM integration test: a request that exceeds memory_limit or
# max_execution_time must terminate only its worker, without running user
# code, and FPM must replace the worker. Requests that end in a regular fatal
# error must not affect later requests served by the same workers.
# usage: ci/fpm-test.sh <php-src-dir built with --enable-fpm>
set -uo pipefail
SRC=$(cd "$1" && pwd)
CI_DIR=$(cd "$(dirname "$0")" && pwd)
. "$CI_DIR/lib.sh"
FAILED=0
prepare_www
RUN=$(mktemp -d)
LOG=$RUN/fpm.log
PORT=9055

cat > "$RUN/php-fpm.conf" <<CONF
[global]
error_log = $LOG
log_level = notice
daemonize = no

[www]
listen = 127.0.0.1:$PORT
pm = static
pm.max_children = 2
catch_workers_output = yes
php_admin_value[error_log] = $RUN/php-errors.log
CONF

"$SRC/sapi/fpm/php-fpm" -c "$WWW/php.ini" -y "$RUN/php-fpm.conf" &
FPM_PID=$!
trap 'kill $FPM_PID 2>/dev/null; echo "----- php-fpm log"; cat "$LOG"' EXIT
for _ in $(seq 1 50); do grep -q 'ready to handle connections' "$LOG" 2>/dev/null && break; sleep 0.2; done
grep -q 'ready to handle connections' "$LOG" || { echo "::error::php-fpm did not start"; exit 1; }

request() { # <script> <query> ; prints the response body
	SCRIPT_FILENAME="$WWW/$1" SCRIPT_NAME="/$1" REQUEST_METHOD=GET QUERY_STRING="$2" \
		cgi-fcgi -bind -connect 127.0.0.1:$PORT 2>/dev/null | tr -d '\r' | sed '1,/^$/d'
}
exits() { grep -c "exited with code $1" "$LOG"; }

check_ok "baseline request" "$(request ok.php n=0)" 0

for i in $(seq 1 20); do
	request fatal.php "" > /dev/null
	check_ok "request $i after a fatal error" "$(request ok.php n=$i)" "$i"
done

before=$(exits 1)
body=$(request oom.php id=fpm)
case "$body" in *unreachable*) fail "oom: script continued after exceeding memory_limit";; esac
sleep 1
check_no_marker oom-fpm
[ "$(exits 1)" -gt "$before" ] && pass "oom: worker exited with code 1" || fail "oom: no worker exit with code 1 in the FPM log"
grep -q 'Allowed memory size of [0-9]* bytes exhausted' "$LOG" && pass "oom: fatal error logged via worker stderr" || fail "oom: fatal error not found in the FPM log"
for i in 1 2 3 4; do check_ok "request $i after OOM (worker replaced)" "$(request ok.php n=$i)" "$i"; done

before=$(exits 124)
request timeout.php id=fpm > /dev/null
sleep 1
check_no_marker timeout-fpm
[ "$(exits 124)" -gt "$before" ] && pass "timeout: worker exited with code 124" || fail "timeout: no worker exit with code 124 in the FPM log"
grep -q 'Maximum execution time of 1 second exceeded (terminated)' "$LOG" && pass "timeout: fatal error logged via worker stderr" || fail "timeout: fatal error not found in the FPM log"
for i in 1 2 3 4; do check_ok "request $i after timeout (worker replaced)" "$(request ok.php n=$i)" "$i"; done

if grep -qE 'exited on signal|SIGSEGV|zend_mm_heap corrupted' "$LOG"; then
	fail "a worker crashed (see FPM log)"
else
	pass "no worker crashed"
fi
exit $FAILED
