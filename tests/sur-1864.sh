#!/usr/bin/env bash
# SUR-1864: bash/trust-server must not overwrite the bash special
# variable $HOSTNAME (auto-maintained by bash; clobbering it interferes
# with PS1, sudo, and update-ca-* hooks). The pre-fix script reassigned
# HOSTNAME / DOMAIN at top level. The fix renamed them to namespaced
# locals and threaded the pem-name parameter into add-certs-amzn /
# add-certs-ubuntu. SUR-1935 later removed the dead CERT_GROUP block
# (and the now-unused cert_host / cert_domain producers it consumed),
# so the dynamic check below only verifies HOSTNAME survival now.
#
# We cannot actually run trust-server (it shells out to openssl, sudo,
# and update-ca-*). Instead, this regression script:
#
#   1. Static check: assert bash/trust-server contains no top-level
#      `HOSTNAME=` assignment.
#   2. Dynamic check: extract the FQDN-parsing block from the live
#      script and source it in a shell that has $HOSTNAME pre-set, then
#      assert $HOSTNAME survives unchanged.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

failures=0
script="$REPO_ROOT/bash/trust-server"

# 1. Static: no `HOSTNAME=...` assignment in the live script.
if grep -nE '^[[:space:]]*HOSTNAME=' "$script" >/dev/null; then
  echo "FAIL: bash/trust-server still assigns to HOSTNAME (bash special var)" >&2
  grep -nE '^[[:space:]]*HOSTNAME=' "$script" >&2
  failures=$((failures + 1))
fi

# 2. Dynamic: source the FQDN-parsing block with HOSTNAME pre-set.
tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT

# Sandboxed HOME so the parsing block (or any helper it might gain in
# the future) cannot scribble in the real user home.
HOME="$tmp_root/home"
mkdir -p "$HOME"
export HOME

# Extract from the `_FQDN=` line through (but not including) the
# `TMPDIR=` line that immediately follows the host/domain-split block.
# Pre-SUR-1935 this used `^fi$` as the terminator, but the dead
# CERT_GROUP block (and its closing `fi`) was deleted in SUR-1935.
fqdn_block="$tmp_root/parse_fqdn.sh"
sed -n '/^_FQDN=/,/^TMPDIR=/{/^TMPDIR=/!p;}' "$script" >"$fqdn_block"

(
  HOSTNAME=preset
  # shellcheck disable=SC2034  # consumed by the sourced block, not by name here
  FQDN=cert.example.com
  # shellcheck source=/dev/null
  source "$fqdn_block"
  if [ "$HOSTNAME" != "preset" ]; then
    echo "FAIL: trust-server FQDN block clobbered \$HOSTNAME (got [$HOSTNAME])" >&2
    exit 1
  fi
)
sub_rc=$?
if [ "$sub_rc" -ne 0 ]; then
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  echo "sur-1864: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
