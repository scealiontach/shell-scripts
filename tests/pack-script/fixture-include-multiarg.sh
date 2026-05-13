# shellcheck shell=bash disable=SC2034
# Fixture for the multi-arg @include regression: the previous awk
# extraction returned the last token. Use unique sentinels so the test
# can assert neither propagates into the packed output as an include
# name. The non-@include comments in this file are deliberately free
# of those sentinel strings so a successful run can be detected by
# their absence in the packed binary.
@include log MULTIARGEXTRAONESENTINEL MULTIARGEXTRATWOSENTINEL
echo "ok"
