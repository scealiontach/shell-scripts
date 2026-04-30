#!/usr/bin/env bash
# SUR-1873: Makefile package targets must declare source-file prerequisites
# so that 'make package' (without 'make clean') detects source changes and
# rebuilds stale tarballs.
#
# Test strategy:
#   1. rm -rf dist && make package — capture baseline tarball checksums.
#      ('make clean' is intentionally avoided to preserve markers/ and build/
#      directories that CI needs for subsequent 'make archive'.)
#   2. Touch a bash/*.sh source file (updating mtime).
#   3. make package (no clean) — assert at least one tarball was regenerated
#      (its checksum changed relative to baseline).

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

failures=0

# sha256sum is Linux-specific; macOS ships shasum -a 256.
checksum() { sha256sum "$1" 2>/dev/null || shasum -a 256 "$1"; }

# Confirm prerequisites are declared in Makefile (static check).
if ! grep -q 'DOC_SRC' "$REPO_ROOT/Makefile"; then
  echo "FAIL: DOC_SRC variable not found in Makefile" >&2
  failures=$((failures + 1))
fi

for target in 'dist/doc-' 'dist/bin-' 'dist/lib-'; do
  # Each target line must list at least one prerequisite (i.e. have a colon
  # followed by something other than whitespace-only or nothing).
  if ! grep -E "^${target}.*\.tar\.gz:.*\S" "$REPO_ROOT/Makefile" >/dev/null 2>&1; then
    echo "FAIL: ${target}*.tar.gz target has no source prerequisites in Makefile" >&2
    failures=$((failures + 1))
  fi
done

# Static check: archive_git zip/tgz targets are marked .PHONY in standard_defs.mk.
# The pattern matches literal $(REPO)-$(VERSION).zip or an already-expanded name
# with the .zip/.tgz suffix.  Single quotes are intentional — we want the shell to
# pass the pattern literally to grep without expanding $(...).
# shellcheck disable=SC2016
if ! grep -q '\.PHONY:.*\.zip\|\.PHONY:.*\.tgz' "$REPO_ROOT/standard_defs.mk"; then
  echo "FAIL: archive_git zip/tgz targets are not .PHONY in standard_defs.mk" >&2
  failures=$((failures + 1))
fi

# Incremental build correctness (functional check).
# We work directly in REPO_ROOT to keep VERSION/git state intact.
# Only dist/ is touched — we deliberately avoid 'make clean' here because
# that would delete markers/ and build/ (via clean_dirs_standard), breaking
# any subsequent 'make archive' call in CI after this test completes.
tmp_root=$(mktemp -d)

# Capture log.sh mtime so we can restore it on cleanup. The 'touch' below
# bumps it to force an incremental rebuild; leaving it bumped pollutes the
# working tree (invisible to git status but visible to subsequent make
# invocations in CI). Use GNU stat first, fall back to BSD on macOS.
log_sh="$REPO_ROOT/bash/log.sh"
log_sh_mtime=$(stat -c '%Y' "$log_sh" 2>/dev/null || stat -f '%m' "$log_sh")

# SC2317 (unreachable inside fn): the body only runs from the EXIT trap.
# SC2329 (fn never invoked): same reason — older shellcheck reports SC2329,
# newer ones SC2317; suppress both so the hook stays portable across versions.
# shellcheck disable=SC2317,SC2329
restore_log_sh_mtime() {
  if [ -n "$log_sh_mtime" ] && [ -f "$log_sh" ]; then
    touch -d "@$log_sh_mtime" "$log_sh" 2>/dev/null ||
      touch -t "$(date -r "$log_sh_mtime" '+%Y%m%d%H%M.%S')" "$log_sh"
  fi
}

trap 'restore_log_sh_mtime; rm -rf "$tmp_root"' EXIT

dist_backup="$tmp_root/dist_backup"
if [ -d "$REPO_ROOT/dist" ]; then
  cp -a "$REPO_ROOT/dist" "$dist_backup"
fi

# Remove only dist/ then do the first package build.
rm -rf "$REPO_ROOT/dist"
(cd "$REPO_ROOT" && make package >/dev/null 2>&1)
build_rc=$?
if [ $build_rc -ne 0 ]; then
  echo "FAIL: 'make package' (fresh dist) exited rc=$build_rc" >&2
  failures=$((failures + 1))
else
  # Record checksums of all produced tarballs.
  declare -A before_sums
  for f in "$REPO_ROOT"/dist/*.tar.gz; do
    [ -f "$f" ] || continue
    before_sums["$(basename "$f")"]=$(checksum "$f" | awk '{print $1}')
  done

  if [ "${#before_sums[@]}" -eq 0 ]; then
    echo "FAIL: no tarballs produced by 'make package'" >&2
    failures=$((failures + 1))
  else
    # Touch a .sh source file to make it newer than the tarballs.
    touch "$REPO_ROOT/bash/log.sh"

    # Incremental rebuild — must regenerate at least one tarball.
    (cd "$REPO_ROOT" && make package >/dev/null 2>&1)
    rebuild_rc=$?
    if [ $rebuild_rc -ne 0 ]; then
      echo "FAIL: incremental 'make package' exited rc=$rebuild_rc" >&2
      failures=$((failures + 1))
    else
      changed=0
      for f in "$REPO_ROOT"/dist/*.tar.gz; do
        [ -f "$f" ] || continue
        name=$(basename "$f")
        after_sum=$(checksum "$f" | awk '{print $1}')
        if [ "${before_sums[$name]}" != "$after_sum" ]; then
          changed=$((changed + 1))
        fi
      done
      if [ "$changed" -eq 0 ]; then
        echo "FAIL: incremental 'make package' did not regenerate any tarball after touching bash/log.sh" >&2
        failures=$((failures + 1))
      fi
    fi
  fi
fi

# Restore dist/ to pre-test state (remove only, no make clean).
rm -rf "$REPO_ROOT/dist"
if [ -d "$dist_backup" ]; then
  cp -a "$dist_backup" "$REPO_ROOT/dist"
fi

if [ "$failures" -ne 0 ]; then
  echo "sur-1873: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
