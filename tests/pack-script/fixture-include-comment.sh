# shellcheck shell=bash disable=SC2034
# Fixture for the @include trailing-comment regression: the previous
# awk extraction returned the trailing token (a ticket name) instead of
# the include name. Use a unique sentinel after the `#` so the test can
# assert it never propagates into the packed output.
@include log # ZZZTRAILINGSENTINELZZZ
echo "ok"
