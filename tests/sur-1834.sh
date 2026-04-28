#!/usr/bin/env bash
# SUR-1834: update-repo-tags must detect Conventional Commits breaking
# changes in BOTH the subject `!:` form (feat!:, fix(scope)!:) and the
# footer `BREAKING CHANGE:` / `BREAKING-CHANGE:` forms. Pre-fix it only
# matched the literal subject "BREAKING CHANGE", so teams using `feat!:`
# silently shipped patch-only bumps for breaking releases.
#
# Behaviour observed via the script's exit code: with a breaking change
# present and no -b flag, the script logs "Minor version changes due to
# breaking changes must be explicitly allowed" and exits 1. With no
# breaking change, it bumps patch (or prerel for lightweight-tag repos)
# and exits 0.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

failures=0
script="$REPO_ROOT/bash/update-repo-tags"

tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT

# Per-fixture committer identity is process-local so the test stays
# self-contained and never reads/writes the user's global git config.
export GIT_AUTHOR_NAME="Test"
export GIT_AUTHOR_EMAIL="test@example.invalid"
export GIT_COMMITTER_NAME="Test"
export GIT_COMMITTER_EMAIL="test@example.invalid"

# Create a fresh synthetic repo with a lightweight v1.0.0 baseline tag.
# Lightweight tags trigger DONT_ANNOTATE_TAG=true inside the script,
# so the no-breaking path applies a lightweight tag without GPG.
make_repo() {
  local dir=$1
  shift
  git init -q -b main "$dir"
  (
    cd "$dir" || exit 1
    git -c commit.gpgsign=false commit -q --allow-empty -m "chore: init"
    git tag v1.0.0
    for msg in "$@"; do
      git -c commit.gpgsign=false commit -q --allow-empty -m "$msg"
    done
  )
}

# Returns rc and stderr from a single update-repo-tags run.
run_script() {
  local dir=$1
  "$script" -t "$dir" 2>&1
}

# The script's "Since X N changes  M breaks" notice is emitted
# unconditionally and surfaces the BREAKING_CHANGES count. log::warn is
# suppressed at default verbosity, so this notice is the test's primary
# probe instead of the warning text.
parse_breaks() {
  local out=$1
  # Strip ANSI colour codes, then capture "M breaks" → M.
  echo "$out" | sed 's/\x1b\[[0-9;]*m//g' |
    sed -nE 's/.* ([0-9]+) breaks.*/\1/p' | tail -n1
}

expect_breaking() {
  local label=$1
  shift
  local dir="$tmp_root/$label"
  make_repo "$dir" "$@"
  local out rc breaks
  out=$(run_script "$dir") && rc=0 || rc=$?
  breaks=$(parse_breaks "$out")
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: $label: expected non-zero rc (breaking detected), got 0" >&2
    echo "$out" >&2
    failures=$((failures + 1))
    return
  fi
  if [ -z "$breaks" ] || [ "$breaks" -lt 1 ]; then
    echo "FAIL: $label: expected at least 1 break in 'Since' notice, got '$breaks'" >&2
    echo "$out" >&2
    failures=$((failures + 1))
  fi
}

expect_no_breaking() {
  local label=$1
  shift
  local dir="$tmp_root/$label"
  make_repo "$dir" "$@"
  local out rc breaks
  out=$(run_script "$dir") && rc=0 || rc=$?
  breaks=$(parse_breaks "$out")
  if [ -n "$breaks" ] && [ "$breaks" -ne 0 ]; then
    echo "FAIL: $label: false-positive breaking detection (breaks=$breaks)" >&2
    echo "$out" >&2
    failures=$((failures + 1))
  fi
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: $label: expected rc=0 for non-breaking history, got $rc" >&2
    echo "$out" >&2
    failures=$((failures + 1))
  fi
}

# 1. feat!: subject only.
expect_breaking "subject-bang" \
  "feat!: drop legacy endpoint"

# 2. feat(scope)!: scoped subject.
expect_breaking "subject-scope-bang" \
  "feat(api)!: rename request field"

# 3. BREAKING CHANGE: footer only (subject is non-breaking type).
expect_breaking "footer-space" \
  "$(printf 'feat: add new option\n\nBREAKING CHANGE: drops the old flag')"

# 4. BREAKING-CHANGE: hyphenated footer.
expect_breaking "footer-hyphen" \
  "$(printf 'fix: tweak parser\n\nBREAKING-CHANGE: parser now requires UTF-8')"

# 5. Mixed: one subject !: commit and one footer commit.
expect_breaking "mixed" \
  "feat!: rotate keys" \
  "$(printf 'fix: handle null\n\nBREAKING CHANGE: must call init() first')"

# 6. Baseline: no breaking changes, just a feat and a fix.
expect_no_breaking "no-breaking" \
  "feat: add stat export" \
  "fix: align logfile path"

# 7. Bootstrap: repo with no v* tag at all should not hard-fail.
bootstrap_dir="$tmp_root/bootstrap"
git init -q -b main "$bootstrap_dir"
(
  cd "$bootstrap_dir" || exit 1
  git -c commit.gpgsign=false commit -q --allow-empty -m "chore: init"
)
out=$("$script" -t "$bootstrap_dir" 2>&1) && rc=0 || rc=$?
case "$out" in
  *"No prior v* tag found"*) ;;
  *)
    echo "FAIL: bootstrap: expected 'No prior v* tag found' notice" >&2
    echo "$out" >&2
    failures=$((failures + 1))
    ;;
esac
# rc may be 0 or non-zero depending on subsequent semver flow; the
# assertion is that the script doesn't hard-fail on the describe call.
case "$out" in
  *"fatal:"*)
    echo "FAIL: bootstrap: leaked git fatal error: rc=$rc" >&2
    echo "$out" >&2
    failures=$((failures + 1))
    ;;
esac

if [ "$failures" -ne 0 ]; then
  echo "sur-1834: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
