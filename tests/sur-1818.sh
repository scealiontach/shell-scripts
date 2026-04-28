#!/usr/bin/env bash
# SUR-1818: pack-script's get_all_includes must emit @include bodies in a
# deterministic order so that two runs over the same target produce
# byte-identical packed output. Pre-fix, the function iterated an
# associative array (hash-dependent ordering) and could shuffle the body
# layout between runs.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

failures=0

# Use a real bin script with multiple transitive @includes as the target,
# so the BFS path is exercised. changelog includes git + options, which in
# turn pull in others.
target="$REPO_ROOT/bash/changelog"
[ -r "$target" ] || {
  echo "FAIL: missing target script: $target" >&2
  exit 1
}

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

run1="$tmpdir/run1.sh"
run2="$tmpdir/run2.sh"

if ! "$REPO_ROOT/bash/pack-script" -f "$target" -o "$run1" >/dev/null 2>&1; then
  echo "FAIL: first pack-script run failed" >&2
  exit 1
fi
if ! "$REPO_ROOT/bash/pack-script" -f "$target" -o "$run2" >/dev/null 2>&1; then
  echo "FAIL: second pack-script run failed" >&2
  exit 1
fi

sum1=$(sha256sum "$run1" | awk '{print $1}')
sum2=$(sha256sum "$run2" | awk '{print $1}')

assert_eq "$sum1" "$sum2" "two pack-script runs produce identical output" ||
  failures=$((failures + 1))

# Smoke: packed file should at minimum start with a shebang.
head1=$(head -1 "$run1")
assert_eq "#!/usr/bin/env bash" "$head1" "packed file has bash shebang" ||
  failures=$((failures + 1))

if [ "$failures" -ne 0 ]; then
  echo "sur-1818: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
