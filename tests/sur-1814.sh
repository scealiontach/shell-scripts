#!/usr/bin/env bash
# SUR-1814: aws::refresh_scan must extract an integer from ECR's float
# imageScanCompletedAt before comparing with `[ -lt ]`. Pre-fix it ran
# `[ "$earliest" -lt "$completedAt" ]` against e.g. 1728310921.123, which
# `[ -lt ]` rejected as "integer expression expected", forcing the cache
# branch to be skipped and triggering a fresh AWS ECR scan on every call.
#
# We exercise aws::refresh_scan in isolation by stubbing
# aws::_describe_findings (the only ECR-touching dependency that gates the
# comparison) and aws::is_scan_complete, then asserting:
#   - a recently-completed (float-timestamp) scan SHORT-CIRCUITS to "within
#     N days" and never invokes aws::scan_image (i.e. no rescan).
#   - an old scan invokes aws::scan_image (rescan).
#   - no `integer expression expected` text leaks to stderr.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

failures=0

# aws.sh's runtime-only relative source of includer.sh cannot be resolved
# at lint time; SC1091 is suppressed for that follow.
# shellcheck source=../bash/aws.sh
# shellcheck disable=SC1091
source "$REPO_ROOT/bash/aws.sh"

# --- Stub the ECR boundary -------------------------------------------------

# Mutable per-fixture: the JSON body aws::_describe_findings will return.
STUB_FINDINGS_JSON=""
# Counter file: aws::scan_image runs in a subshell when refresh_scan is
# invoked under $(...), so a plain variable wouldn't survive. The stub
# appends a byte to this marker file instead, and the parent counts bytes.
SCAN_IMAGE_MARKER=$(mktemp)
trap 'rm -f "$SCAN_IMAGE_MARKER"' EXIT

reset_marker() { : >"$SCAN_IMAGE_MARKER"; }
scan_image_calls() { wc -c <"$SCAN_IMAGE_MARKER" | tr -d ' '; }

aws::_describe_findings() {
  echo "$STUB_FINDINGS_JSON"
}
aws::is_scan_complete() {
  return 0
}
aws::scan_image() {
  printf 'x' >>"$SCAN_IMAGE_MARKER"
}

# --- Fixture 1: float timestamp, recent. Cache should hold. ----------------

now=$(date +%s)
recent=$((now - 3600)) # 1h ago
STUB_FINDINGS_JSON=$(printf '{"imageScanFindings":{"imageScanCompletedAt":%s.567}}' "$recent")
reset_marker

err=$(aws::refresh_scan repo tag 7 2>&1)
rc=$?
assert_zero "$rc" "refresh_scan returns rc=0 on cache hit" ||
  failures=$((failures + 1))
assert_eq "0" "$(scan_image_calls)" "no rescan on cache hit" ||
  failures=$((failures + 1))
case "$err" in
  *"integer expression expected"*)
    echo "FAIL: 'integer expression expected' leaked to stderr:" >&2
    echo "$err" >&2
    failures=$((failures + 1))
    ;;
esac

# --- Fixture 2: float timestamp, older than 7 days. Cache miss. ------------

old=$((now - 30 * 86400)) # 30d ago
STUB_FINDINGS_JSON=$(printf '{"imageScanFindings":{"imageScanCompletedAt":%s.123}}' "$old")
reset_marker

err=$(aws::refresh_scan repo tag 7 2>&1)
rc=$?
assert_eq "1" "$(scan_image_calls)" "rescan triggered when scan older than threshold" ||
  failures=$((failures + 1))
case "$err" in
  *"integer expression expected"*)
    echo "FAIL: 'integer expression expected' leaked to stderr:" >&2
    echo "$err" >&2
    failures=$((failures + 1))
    ;;
esac

# --- Fixture 3: list_findings uses aws::_jq, not bare jq -------------------

# Smoke: aws::list_findings must hand off through aws::_describe_findings
# (stubbed above to echo STUB_FINDINGS_JSON). With a synthetic findings doc,
# the function should produce one row per finding without error. The pre-fix
# bare `jq` call would have bypassed commands::use jq's missing-jq guard;
# this assertion gives the pipe a real exercise.
STUB_FINDINGS_JSON='{
  "imageScanFindings": {
    "findings": [
      {"severity": "HIGH", "name": "CVE-2024-0001", "uri": "https://x/1"},
      {"severity": "LOW",  "name": "CVE-2024-0002", "uri": "https://x/2"}
    ]
  }
}'
out=$(aws::list_findings repo tag 2>&1)
rc=$?
assert_zero "$rc" "list_findings returns rc=0 on synthetic findings" ||
  failures=$((failures + 1))
case "$out" in
  *"HIGH CVE-2024-0001 https://x/1"*) ;;
  *)
    echo "FAIL: list_findings missing first row: $out" >&2
    failures=$((failures + 1))
    ;;
esac
case "$out" in
  *"LOW CVE-2024-0002 https://x/2"*) ;;
  *)
    echo "FAIL: list_findings missing second row: $out" >&2
    failures=$((failures + 1))
    ;;
esac

if [ "$failures" -ne 0 ]; then
  echo "sur-1814: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
