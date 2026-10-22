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

prepare_www() {
	WWW=$(mktemp -d)
	cp "$CI_DIR"/www/*.php "$WWW"/
	mkdir -p "$WWW/markers"
	chmod -R a+rwX "$WWW"
}
