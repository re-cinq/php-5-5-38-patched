#!/usr/bin/env bash
# PHP-FPM integration test: a request that exceeds memory_limit or
# max_execution_time must terminate only its worker, without running user
# code, and FPM must replace the worker. A bailout during request cleanup must
# leave clean state for the next request in the same worker.
# usage: ci/fpm-test.sh <php-src-dir built with --enable-fpm>
set -uo pipefail
SRC=$(cd "$1" && pwd)
CI_DIR=$(cd "$(dirname "$0")" && pwd)
. "$CI_DIR/lib.sh"
FAILED=0
prepare_www fpm
RUN=$(mktemp -d)
LOG=$RUN/fpm.log
PORT=9055

# Test setup plus the shipped hardening (config/php2shell)
{
	cat <<CONF
[global]
error_log = $LOG
log_level = notice
daemonize = no
CONF
	cat "$CONFIG_DIR/php-fpm-global.conf"
	cat <<CONF

[www]
listen = 127.0.0.1:$PORT
pm = static
pm.max_children = 1
php_admin_value[error_log] = $RUN/php-errors.log
CONF
	# Keep the production limit administratively locked, but shorten its value
	# in this generated test config. FPM keeps the first duplicate pool value,
	# so appending a second directive would leave the shipped 30s in effect.
	sed 's/^php_admin_value\[max_execution_time\] = 30$/php_admin_value[max_execution_time] = 1/' \
		"$CONFIG_DIR/php-fpm-pool.conf"
} > "$RUN/php-fpm.conf"

"$SRC/sapi/fpm/php-fpm" -c "$WWW/php.ini" -y "$RUN/php-fpm.conf" -t || { echo "::error::php-fpm configuration test failed"; exit 1; }
pass "php-fpm configuration test"

"$SRC/sapi/fpm/php-fpm" -c "$WWW/php.ini" -y "$RUN/php-fpm.conf" &
FPM_PID=$!
cleanup_fpm() {
	kill "$FPM_PID" 2>/dev/null
	# FPM should stop within process_control_timeout (10s). Never let an EXIT
	# trap hide the test result by waiting forever on a retained child.
	for _ in $(seq 1 150); do
		kill -0 "$FPM_PID" 2>/dev/null || break
		sleep 0.1
	done
	if kill -0 "$FPM_PID" 2>/dev/null; then
		echo "::warning::php-fpm did not stop within 15s; killing the master"
		kill -KILL "$FPM_PID" 2>/dev/null
	fi
	wait "$FPM_PID" 2>/dev/null
	echo "----- php-fpm log"
	cat "$LOG"
}
trap cleanup_fpm EXIT
for _ in $(seq 1 50); do grep -q 'ready to handle connections' "$LOG" 2>/dev/null && break; sleep 0.2; done
grep -q 'ready to handle connections' "$LOG" || { echo "::error::php-fpm did not start"; exit 1; }

raw_request() { # <script> <query> ; prints headers and body
	DOCUMENT_ROOT="$WWW" SCRIPT_FILENAME="$WWW/$1" SCRIPT_NAME="/$1" \
		REQUEST_METHOD=GET QUERY_STRING="${2:-}" \
		timeout 60 cgi-fcgi -bind -connect 127.0.0.1:$PORT 2>/dev/null | tr -d '\r'
}
request() { raw_request "$@" | sed '1,/^$/d'; }
exits() { grep -c "exited with code $1" "$LOG"; }

check_ok "baseline request" "$(request ok.php n=0)" 0

check_settings "$(request settings.php)" 1
raw_request ok.php n=0 | sed '/^$/q' | grep -qi '^X-Powered-By' && fail "X-Powered-By header exposed" || pass "no X-Powered-By header"

# A body above post_max_size is not parsed into $_POST. The body must really
# be CONTENT_LENGTH bytes long, otherwise the request never completes.
head -c $((9 * 1024 * 1024)) /dev/zero | tr '\0' 'a' | sed '1s/^/a=1\&b=/' | head -c $((9 * 1024 * 1024)) > "$RUN/big-body"
body=$(DOCUMENT_ROOT="$WWW" SCRIPT_FILENAME="$WWW/settings.php" SCRIPT_NAME=/settings.php REQUEST_METHOD=POST \
	CONTENT_TYPE=application/x-www-form-urlencoded CONTENT_LENGTH=$(wc -c < "$RUN/big-body" | tr -d ' ') \
	timeout 60 cgi-fcgi -bind -connect 127.0.0.1:$PORT < "$RUN/big-body" 2>/dev/null | tr -d '\r' | sed '1,/^$/d')
grep -qx 'post_vars=0' <<<"$body" && pass "body above post_max_size discarded" || fail "body above post_max_size was parsed"
check_ok "request after oversized POST" "$(request ok.php n=0)" 0

for i in $(seq 1 20); do
	check_cleanup_reuse "cleanup bailout $i"
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

# Timeout stress (see ci/www/stress.php)
STRESS_N=30
before=$(grep -c 'Maximum execution time of 1 second exceeded (terminated)' "$LOG")
for i in $(seq 1 $STRESS_N); do
	request stress.php "" > /dev/null
	rc=$?
	# cgi-fcgi reports the expected worker-side hard exit as a nonzero status.
	# Only status 124 means our outer 60-second timeout actually expired.
	if [ $rc -eq 124 ]; then
		fail "stress request $i did not complete within 60 seconds"
		break
	fi
done
sleep 1
check_stress "$LOG" $STRESS_N "$before"
for i in 1 2 3 4; do check_ok "request $i after stress" "$(request ok.php n=$i)" "$i"; done

if grep -qE 'exited on signal|SIGSEGV|zend_mm_heap corrupted' "$LOG"; then
	fail "a worker crashed (see FPM log)"
else
	pass "no worker crashed"
fi
exit $FAILED
