#!/usr/bin/env bats
# SUR-1857: pull_if_different used to clobber the script-scope branch_name
# loop variable because $2 was assigned without `local`. Drive git-check
# end-to-end against two repos on different branches and assert each
# per-repo line carries the correct branch.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  helpers::set_git_identity
  # tput needs a terminfo entry; xterm is universally present and lets the
  # script's color escapes resolve. We strip ANSI from the output before
  # asserting, so the codes themselves are immaterial to the check.
  export TERM=xterm
  GIT_CHECK="$REPO_ROOT/bash/git-check"
  export GIT_CHECK

  mkdir -p "$HOME/git/testbase/orgA" "$HOME/git/testbase/orgB"
  init_repo "$HOME/git/testbase/orgA/repoA" branchA
  init_repo "$HOME/git/testbase/orgB/repoB" branchB
}

# Build a single-commit repo on the given branch (no remote — git-check's
# fetch/diff/pull steps fail silently because the script does not run
# under set -e).
init_repo() {
  local dir=$1 branch=$2
  git init -q -b main "$dir"
  (
    cd "$dir" || exit 1
    echo seed >file
    git add file
    git -c commit.gpgsign=false commit -q -m seed
    git checkout -q -b "$branch"
  )
}

@test "pull_if_different declares branch_name local (does not leak to caller)" {
  # Extract the function definition from git-check verbatim, source it
  # into a fresh shell with a stubbed git::cmd, set an outer branch_name,
  # invoke the function, and assert the outer scope is unchanged.
  run bash -c "
    set -e
    # Stub git::cmd / log / exec functions used by pull_if_different.
    git::cmd() { :; }
    log::info() { :; }
    log::notice() { :; }
    exec::hide() { :; }
    # Source just the function body via awk extraction.
    eval \"\$(awk '/^function pull_if_different /,/^}\$/' '$REPO_ROOT/bash/git-check')\"
    branch_name=outer
    pull_if_different x inner
    [ \"\$branch_name\" = outer ]
  "
  [ "$status" -eq 0 ]
}

@test "git-check emits per-repo lines with the correct branch column" {
  run bash -c "'$GIT_CHECK' -b testbase 2>/dev/null"
  # Strip ANSI escape sequences (tput setaf / sgr0) so the per-repo line
  # can be matched purely on text content.
  clean=$(printf '%s\n' "$output" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g')
  # Each output line has the form: "<name> <pr_count> <branch> <version>"
  # with column-padded fields. Match name + branch on the same line.
  echo "$clean" | grep -E 'orgA/repoA[[:space:]].*[[:space:]]branchA[[:space:]]'
  echo "$clean" | grep -E 'orgB/repoB[[:space:]].*[[:space:]]branchB[[:space:]]'
}

@test "git-check buckets a repo with uncommitted changes as UNCOMMITTED" {
  mkdir -p "$HOME/git/uchk/org"
  helpers::make_fixture_repo "$HOME/git/uchk/org/repo" --tagged
  # Unstaged modification causes --dirty to append the -dirty suffix.
  echo "dirty" >>"$HOME/git/uchk/org/repo/README"

  run bash -c "'$GIT_CHECK' -b uchk 2>/dev/null"
  clean=$(printf '%s\n' "$output" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g')
  echo "$clean" | grep -E 'org/repo'
  echo "$clean" | grep '\-dirty'
}

@test "git-check buckets a clean repo at a tag as RELEASABLE" {
  mkdir -p "$HOME/git/rchk/org"
  helpers::make_fixture_repo "$HOME/git/rchk/org/repo" --tagged

  run bash -c "'$GIT_CHECK' -b rchk 2>/dev/null"
  clean=$(printf '%s\n' "$output" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g')
  echo "$clean" | grep -E 'org/repo'
  echo "$clean" | grep -E 'v0\.3\.0[[:space:]]'
}

@test "git-check buckets a clean repo ahead of a tag as DEVELOPMENT" {
  mkdir -p "$HOME/git/dchk/org"
  helpers::make_fixture_repo "$HOME/git/dchk/org/repo" --tagged
  echo "extra" >>"$HOME/git/dchk/org/repo/README"
  git -C "$HOME/git/dchk/org/repo" add README
  git -C "$HOME/git/dchk/org/repo" -c commit.gpgsign=false commit -q -m "feat: extra"

  run bash -c "'$GIT_CHECK' -b dchk 2>/dev/null"
  clean=$(printf '%s\n' "$output" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g')
  echo "$clean" | grep -E 'org/repo'
  echo "$clean" | grep -E 'v0\.3\.0-[0-9]+-g'
}

@test "git-check restores caller working directory after scanning repos (SUR-2470)" {
  run bash -c "
    cd /tmp || exit 1
    before=\$PWD
    '$GIT_CHECK' -b testbase >/dev/null 2>&1
    [ \"\$PWD\" = \"\$before\" ]
  "
  [ "$status" -eq 0 ]
}
