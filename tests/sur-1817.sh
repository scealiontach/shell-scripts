#!/usr/bin/env bash
# SUR-1817: pack-script must rewrite every BASH_SOURCE[N] index (0, 1, 2,
# negative) in the target file to BASH_SOURCE[0]. The pre-fix sed used
# `[\d]` which matches a literal `\` or `d` inside a character class and so
# never rewrote real call sites like BASH_SOURCE[0]/[1]/[-1].

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

failures=0

fixture="$TEST_DIR/pack-script/fixture-source-indices.sh"
[ -r "$fixture" ] || {
  echo "FAIL: fixture missing: $fixture" >&2
  exit 1
}

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
out="$tmpdir/packed.sh"

if ! "$REPO_ROOT/bash/pack-script" -f "$fixture" -o "$out" >/dev/null 2>&1; then
  echo "FAIL: pack-script exited non-zero on fixture" >&2
  exit 1
fi

# Sanity: the packed file should be non-empty (proving the pipeline actually
# ran and wrote content). The earlier `if ! pack-script ...; then exit 1; fi`
# guarantees a zero exit, so $? here would always be 0; assert on the artifact
# instead.
[ -s "$out" ] || {
  echo "FAIL: packed output is empty" >&2
  failures=$((failures + 1))
}

# After the fix, no BASH_SOURCE[<non-zero or negative>] should remain in the
# packed body that came from the target file. Note: doc.sh / annotations.sh /
# included libraries also legitimately reference BASH_SOURCE[0] so we only
# assert the absence of indices != 0.
if grep -E 'BASH_SOURCE\[(-[0-9]+|[1-9][0-9]*)\]' "$out" >/dev/null; then
  echo "FAIL: packed output still contains non-zero BASH_SOURCE index:" >&2
  grep -nE 'BASH_SOURCE\[(-[0-9]+|[1-9][0-9]*)\]' "$out" >&2
  failures=$((failures + 1))
fi

# And the rewrite should have produced at least one BASH_SOURCE[0] from the
# fixture content (the fixture had four such references).
if ! grep -q 'BASH_SOURCE\[0\]' "$out"; then
  echo "FAIL: packed output is missing BASH_SOURCE[0] entirely" >&2
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  echo "sur-1817: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
