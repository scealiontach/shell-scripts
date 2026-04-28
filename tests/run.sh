#!/usr/bin/env bash
# Sprint test runner: executes every tests/sur-*.sh file in a fresh subshell.
# Exits non-zero if any test file fails.

TESTS_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TESTS_DIR
REPO_ROOT="$(cd -P "$TESTS_DIR/.." && pwd)"
export REPO_ROOT

pass=0
fail=0
failed_tests=()

shopt -s nullglob
for t in "$TESTS_DIR"/sur-*.sh; do
  name=$(basename "$t")
  if bash "$t"; then
    pass=$((pass + 1))
    echo "PASS $name"
  else
    fail=$((fail + 1))
    failed_tests+=("$name")
    echo "FAIL $name"
  fi
done

echo "----"
echo "passed: $pass  failed: $fail"
if [ "$fail" -ne 0 ]; then
  for n in "${failed_tests[@]}"; do
    echo "  - $n"
  done
  exit 1
fi
exit 0
