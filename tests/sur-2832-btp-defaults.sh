#!/usr/bin/env bash
# SUR-2832: hardcoded BTP / blockchaintp identifiers have been promoted
# to overridable environment variables. Lock down both contracts:
#   1. The default of each env var matches the historical literal so the
#      refactor cannot silently regress callers that relied on the
#      previous behaviour.
#   2. The promoted env var actually takes effect when set (covers the
#      AWS_SCAN_SKIP_REPOS path through aws::scan).

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

failures=0

# --- Default literals ----------------------------------------------------

# release-images: source organization default is "blockchaintp".
out=$(grep -E '^RELEASE_IMAGES_ORG=' "$REPO_ROOT/bash/release-images")
assert_contains "$out" "blockchaintp" \
  "release-images RELEASE_IMAGES_ORG default preserves blockchaintp" ||
  failures=$((failures + 1))

# review-prs: org list default is "391agency btpworks blockchaintp catenasys".
out=$(grep -E '^REVIEW_PRS_ORGS=' "$REPO_ROOT/bash/review-prs")
assert_contains "$out" "391agency btpworks blockchaintp catenasys" \
  "review-prs REVIEW_PRS_ORGS default preserves BTP-era org list" ||
  failures=$((failures + 1))

out=$(grep -E '^REVIEW_PRS_INTEREST_ORGS=' "$REPO_ROOT/bash/review-prs")
assert_contains "$out" "hyperledger" \
  "review-prs REVIEW_PRS_INTEREST_ORGS default preserves hyperledger" ||
  failures=$((failures + 1))

# git-check: GH org default is "blockchaintp catenasys scealiontach".
out=$(grep -E 'GIT_CHECK_GH_ORGS:-' "$REPO_ROOT/bash/git-check")
assert_contains "$out" "blockchaintp catenasys scealiontach" \
  "git-check GIT_CHECK_GH_ORGS default preserves BTP-era org list" ||
  failures=$((failures + 1))

out=$(grep -E 'GIT_CHECK_BB_ORGS:-' "$REPO_ROOT/bash/git-check")
assert_contains "$out" "TASE" \
  "git-check GIT_CHECK_BB_ORGS default preserves TASE" ||
  failures=$((failures + 1))

# pagerduty-alert: default From address is no-reply@blockchaintp.com.
out=$(grep -E 'PAGERDUTY_FROM_DEFAULT:-' "$REPO_ROOT/bash/pagerduty-alert")
assert_contains "$out" "no-reply@blockchaintp.com" \
  "pagerduty-alert PAGERDUTY_FROM_DEFAULT preserves BTP From address" ||
  failures=$((failures + 1))

# aws.sh: default skip list is blockchaintp/busybox.
out=$(grep -E 'AWS_SCAN_SKIP_REPOS:-' "$REPO_ROOT/bash/aws.sh")
assert_contains "$out" "blockchaintp/busybox" \
  "aws.sh AWS_SCAN_SKIP_REPOS default preserves blockchaintp/busybox" ||
  failures=$((failures + 1))

# docker.sh: default version patterns retain the historical BTP regex.
out=$(grep -E "default_pattern='BTP" "$REPO_ROOT/bash/docker.sh")
assert_contains "$out" "BTP" \
  "docker::list_versions default_pattern preserves the BTP regex" ||
  failures=$((failures + 1))

out=$(grep -E "default_pattern='\^BTP" "$REPO_ROOT/bash/docker.sh")
assert_contains "$out" "^BTP" \
  "docker::list_official_versions default_pattern preserves the anchored BTP regex" ||
  failures=$((failures + 1))

# --- AWS_SCAN_SKIP_REPOS override actually takes effect -----------------

# Drive aws::scan with stubbed aws::get_repositories and aws::scan_repository
# to assert the override skips additional repos.
override_out=$(
  # shellcheck source=/dev/null
  source "$REPO_ROOT/bash/includer.sh"
  @include aws

  # Stub out the AWS calls so the test runs without aws on PATH.
  # shellcheck disable=SC2317,SC2329 # invoked indirectly by sourced aws::scan
  aws::get_repositories() { printf 'blockchaintp/busybox\nblockchaintp/foo\nacme/bar\n'; }
  # shellcheck disable=SC2317,SC2329 # invoked indirectly by sourced aws::scan
  aws::scan_repository() { echo "SCAN $1 $2"; }

  AWS_SCAN_SKIP_REPOS="blockchaintp/busybox,blockchaintp/foo" aws::scan some-tag 2>/dev/null
)
# Only acme/bar should be scanned.
assert_contains "$override_out" "SCAN acme/bar some-tag" \
  "AWS_SCAN_SKIP_REPOS override leaves non-skipped repos scannable" ||
  failures=$((failures + 1))
case "$override_out" in
  *"SCAN blockchaintp/foo"*)
    echo "FAIL: AWS_SCAN_SKIP_REPOS did not skip blockchaintp/foo" >&2
    failures=$((failures + 1))
    ;;
esac

if [ "$failures" -ne 0 ]; then
  echo "sur-2832: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
