#!/usr/bin/env bash
# Run PHP's own test runner on a built tree and keep its output.
# usage: ci/run-suite.sh <php-src-dir> <output-log> <test paths...>
set -uo pipefail
src=$1; out=$2; shift 2
cd "$src"
TEST_PHP_EXECUTABLE=sapi/cli/php TEST_PHP_CGI_EXECUTABLE=sapi/cgi/php-cgi NO_INTERACTION=1 \
  sapi/cli/php -n run-tests.php -q "$@" > "$out" 2>&1
# run-tests.php exits 0 even with failures; results are evaluated by ci/compare.py
exit 0
