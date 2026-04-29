#!/usr/bin/env bash
# SUR-1862: bash/changelog ::full must:
#   1. emit a deterministic markdown changelog driven only by tags +
#      commit subjects (no caller-scope state leaks into the loop), and
#   2. resolve `git::describe` through bash/git.sh rather than calling
#      bare `git describe`.
#
# We exercise both via a synthetic fixture repo with three tagged
# commits on pinned author/committer dates, then compare the captured
# output against a heredoc golden. Hashes and author/committer dates
# are not part of the rendered output, so the golden is hash-stable.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

failures=0
script="$REPO_ROOT/bash/changelog"

tmp_repo=$(mktemp -d)
trap 'rm -rf "$tmp_repo"' EXIT

# Pin git identity + dates so the fixture is deterministic and never
# reads/writes the user's global git config.
export GIT_AUTHOR_NAME="Bats Tester"
export GIT_AUTHOR_EMAIL="bats@example.invalid"
export GIT_COMMITTER_NAME="Bats Tester"
export GIT_COMMITTER_EMAIL="bats@example.invalid"

git init -q -b main "$tmp_repo"

commit_at() {
  local when=$1
  local msg=$2
  GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" \
    git -C "$tmp_repo" -c commit.gpgsign=false \
    commit -q --allow-empty -m "$msg"
}

commit_at "2024-01-01T00:00:00 +0000" "feat: c1 baseline"
git -C "$tmp_repo" tag v0.1.0
commit_at "2024-02-01T00:00:00 +0000" "feat: c2 second"
commit_at "2024-03-01T00:00:00 +0000" "feat: c3 third"
git -C "$tmp_repo" tag v0.2.0
commit_at "2024-04-01T00:00:00 +0000" "feat: c4 fourth"
git -C "$tmp_repo" tag v0.3.0

# Run bash/changelog from inside the fixture repo (it relies on CWD
# for git operations).
out=$(cd "$tmp_repo" && "$script")

# Heredoc golden. ::fromto appends two echos after each commit listing,
# but git log --pretty=format: emits no trailing newline, so the net
# spacing between sections is a single blank line. Command substitution
# also strips the trailing newline.
expected=$(
  cat <<'EOF'
# CHANGELOG

## v0.3.0

* feat: c4 fourth

## v0.2.0

* feat: c3 third
* feat: c2 second
EOF
)

if [ "$out" != "$expected" ]; then
  echo "FAIL: changelog output did not match golden" >&2
  echo "----- expected -----" >&2
  echo "$expected" >&2
  echo "----- got -----" >&2
  echo "$out" >&2
  echo "----- diff -----" >&2
  diff <(echo "$expected") <(echo "$out") >&2
  failures=$((failures + 1))
fi

# Belt-and-braces: confirm ::full no longer reads bare `git describe`.
# The fix replaces it with `git::describe`. Grepping the source is a
# cheap regression check that the bare call doesn't sneak back in.
if grep -nE '^\s*[a-zA-Z_]*=\$\(git describe' "$script" >/dev/null; then
  echo "FAIL: bash/changelog still calls bare 'git describe'" >&2
  grep -nE '^\s*[a-zA-Z_]*=\$\(git describe' "$script" >&2
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  echo "sur-1862: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
