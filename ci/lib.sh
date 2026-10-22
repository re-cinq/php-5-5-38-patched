# Shared helpers for the SAPI integration tests.
fail() { echo "::error::$*"; FAILED=1; }
pass() { echo "PASS: $*"; }

# Each test page writes a marker file from its shutdown function. After an
# OOM or timeout the worker must terminate before any user code runs, so no
# marker may exist.
check_no_marker() {
	local name=$1
	if [ -e "$WWW/markers/$name" ]; then
		fail "$name: shutdown function ran after the fatal error"
	else
		pass "$name: shutdown function did not run"
	fi
}

check_ok() {
	local label=$1 body=$2 n=$3
	if [ "$body" = "ok $n" ]; then
		pass "$label"
	else
		fail "$label: expected 'ok $n', got '$body'"
	fi
}

check_cleanup_reuse() {
	local label=$1 before after expected
	rm -f "$WWW/markers/fatal-pid"
	request fatal.php > /dev/null
	before=$(cat "$WWW/markers/fatal-pid" 2>/dev/null)
	after=$(request cleanup-state.php 'probe%5Bvalue%5D=clean')
	expected="clean pid=$before"
	if [ -n "$before" ] && [ "$after" = "$expected" ]; then
		pass "$label (worker $before reused with clean state)"
	else
		fail "$label: expected '$expected', got '$after'"
	fi
}

CONFIG_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../config/php2shell" && pwd)

# Settings from config/php2shell that must be in effect
check_settings() {
	local out=$1
	local kv k
	for kv in 'max_file_uploads=20' 'max_input_nesting_level=16' 'max_input_time=30' \
		'max_input_vars=1000' 'max_multipart_body_parts=-1' 'memory_limit=128M' \
		'post_max_size=8M' 'upload_max_filesize=8M' 'override_probe=12'; do
		if grep -qxF "$kv" <<<"$out"; then pass "setting $kv"; else fail "setting $kv not in effect"; fi
	done
	# Booleans read back as "" (php.ini Off) or "0" (php_admin_flag off)
	for k in session.upload_progress.enabled expose_php display_errors; do
		if grep -qxE "$k=0?" <<<"$out"; then pass "setting $k off"; else fail "setting $k not off: $(grep "^$k=" <<<"$out")"; fi
	done
}

# After the stress run: every request must have terminated its process
# cleanly, no shutdown function may have run, and nothing may have corrupted
# the heap. <log> <requests>
check_stress() {
	local log=$1 n=$2 terminated
	# Only count stress.php: the earlier timeout.php test logs the same message
	terminated=$(grep -c 'Maximum execution time of 1 second exceeded (terminated) in .*/stress\.php' "$log")
	[ "$terminated" -eq "$n" ] && pass "stress: $terminated/$n requests terminated cleanly" \
		|| fail "stress: only $terminated/$n requests terminated with the hard-exit message"
	if ls "$WWW"/markers/stress-* >/dev/null 2>&1; then
		fail "stress: a shutdown function ran after the timeout"
	else
		pass "stress: no shutdown function ran"
	fi
	grep -q 'zend_mm_heap corrupted' "$log" && fail "stress: heap corruption detected" || pass "stress: no heap corruption"
}

prepare_www() {
	local sapi=$1
	WWW=$(mktemp -d)
	cp "$CI_DIR"/www/*.php "$WWW"/
	# The shipped hardening settings are the php.ini under test
	cp "$CONFIG_DIR/zz-php2shell.ini" "$WWW/php.ini"
	case "$sapi" in
		fpm) cp "$CI_DIR/www/fpm-overrides.ini" "$WWW/.user.ini" ;;
		apache) cp "$CI_DIR/www/apache-overrides.htaccess" "$WWW/.htaccess" ;;
		*) echo "::error::unknown SAPI '$sapi'"; exit 1 ;;
	esac
	mkdir -p "$WWW/markers"
	chmod -R a+rwX "$WWW"
	[ -f "$WWW/php.ini" ] || { echo "::error::php.ini missing"; exit 1; }
}
