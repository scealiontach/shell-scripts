#!/usr/bin/env bash
# SUR-1852: pack-script-produced binaries must actually run end-to-end and
# the packed body must not contain `@include` directives or `includer.sh`
# references. Parameterised over more than one command script to prove
# coverage isn't accidentally pegged to a single input.
#
# Companion regressions covered by sibling tests:
#   sur-1817.sh: BASH_SOURCE[N] index rewriting.
#   sur-1818.sh: byte-identical repeated packs.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

failures=0

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Targets parameterise the smoke run over multiple command scripts. Both
# pull in non-trivial transitive @includes (git, options, log).
targets=(
  "$REPO_ROOT/bash/changelog"
  "$REPO_ROOT/bash/clean-branches"
)

for target in "${targets[@]}"; do
  base=$(basename "$target")
  out="$tmpdir/$base"

  if ! "$REPO_ROOT/bash/pack-script" -f "$target" -o "$out" >/dev/null 2>&1; then
    echo "FAIL: pack-script exited non-zero on $base" >&2
    failures=$((failures + 1))
    continue
  fi

  [ -s "$out" ] || {
    echo "FAIL: packed output empty for $base" >&2
    failures=$((failures + 1))
    continue
  }

  if ! bash -n "$out" 2>/dev/null; then
    echo "FAIL: packed $base failed bash -n syntax check" >&2
    failures=$((failures + 1))
  fi

  if grep -q "^@include" "$out"; then
    echo "FAIL: packed $base still contains @include lines:" >&2
    grep -n "^@include" "$out" >&2
    failures=$((failures + 1))
  fi

  if grep -q "includer.sh" "$out"; then
    echo "FAIL: packed $base still references includer.sh:" >&2
    grep -n "includer.sh" "$out" >&2
    failures=$((failures + 1))
  fi

  # Smoke run -h. options::syntax_exit returns rc=1 by design; the value of
  # rc isn't the assertion. The assertion is that the script loaded its
  # libraries without a "command not found" / syntax error and reached the
  # SYNTAX section.
  chmod +x "$out"
  help_out=$("$out" -h 2>&1 || true)
  case "$help_out" in
    *SYNTAX*) ;;
    *)
      echo "FAIL: packed $base did not print SYNTAX on -h:" >&2
      echo "$help_out" >&2
      failures=$((failures + 1))
      ;;
  esac
done

if [ "$failures" -ne 0 ]; then
  echo "sur-1852: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
