#!/usr/bin/env bash
# Build PHP 5.5 from a source tree with a modern GCC.
# usage: ci/build.sh <source-dir> [extra configure args...]
set -euo pipefail
src=$1; shift
cd "$src"
# PHP 5.5 predates GCC 10 (-fno-common default) and newer diagnostics.
# -fwrapv/-fno-strict-aliasing keep the old signed-overflow/aliasing behaviour it relies on.
export CFLAGS="-O2 -g -std=gnu89 -fcommon -fwrapv -fno-strict-aliasing \
  -Wno-implicit-function-declaration -Wno-incompatible-pointer-types -Wno-int-conversion"
./configure --disable-all --enable-cli --enable-session --without-pear --without-iconv "$@" \
  > configure.log 2>&1 || { tail -50 configure.log; exit 1; }
make -j"$(nproc)" > make.log 2>&1 || { grep -n -B2 -A5 'error' make.log | head -80; exit 1; }
./sapi/cli/php -v
