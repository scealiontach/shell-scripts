#!/usr/bin/env bash
# SUR-1840: lib-funcs-must-be-namespaced lint hook (tests/check-lib-namespaces.sh)
# must:
#   1. flag bare `function foo()` definitions when run against a fixture file
#      placed under bash/<name>.sh,
#   2. ignore namespaced `function foo::bar()` definitions,
#   3. ignore the parens-only `foo() { ... }` shim form (still permitted by
#      AGENTS.md for backward-compat shims), and
#   4. report rc=0 on the live `bash/*.sh` tree as it stands today.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
HOOK="$REPO_ROOT/tests/check-lib-namespaces.sh"
FIXTURE="$REPO_ROOT/tests/fixtures/bare_function.sh"

failures=0

# Fixture 1: live tree must be clean.
if ! "$HOOK" "$REPO_ROOT"/bash/*.sh >/dev/null 2>&1; then
  echo "FAIL: live bash/*.sh tree triggers lint-funcs-must-be-namespaced" >&2
  "$HOOK" "$REPO_ROOT"/bash/*.sh >&2
  failures=$((failures + 1))
fi

# Fixture 2: fixture file (placed under bash/) must trigger the hook.
# We have to relocate it temporarily because the hook's per-file `case`
# guard only inspects paths under bash/.
TMPDIR_LINT=$(mktemp -d)
trap 'rm -rf "$TMPDIR_LINT"' EXIT
mkdir -p "$TMPDIR_LINT/bash"
cp "$FIXTURE" "$TMPDIR_LINT/bash/zz_bare.sh"

(
  cd "$TMPDIR_LINT" && "$HOOK" bash/zz_bare.sh
) >/dev/null 2>"$TMPDIR_LINT/err"
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL: fixture with bare function did not trigger lint" >&2
  failures=$((failures + 1))
fi
if ! grep -q 'bare_offender' "$TMPDIR_LINT/err"; then
  echo "FAIL: lint output did not name 'bare_offender':" >&2
  cat "$TMPDIR_LINT/err" >&2
  failures=$((failures + 1))
fi
if grep -q 'bare_namespaced::ok' "$TMPDIR_LINT/err"; then
  echo "FAIL: lint flagged a namespaced function (false positive)" >&2
  cat "$TMPDIR_LINT/err" >&2
  failures=$((failures + 1))
fi

# Fixture 3: parens-only shim form must NOT trip the hook.
cat >"$TMPDIR_LINT/bash/zz_shim.sh" <<'EOF'
#!/usr/bin/env bash
shim_only() {
  echo "parens-only is fine"
}
EOF
if ! (cd "$TMPDIR_LINT" && "$HOOK" bash/zz_shim.sh) >/dev/null 2>&1; then
  echo "FAIL: parens-only shim form falsely tripped lint" >&2
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  echo "sur-1840: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
