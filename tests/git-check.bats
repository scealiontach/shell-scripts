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
