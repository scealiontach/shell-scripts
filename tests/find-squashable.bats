#!/usr/bin/env bats
# SUR-1882: find-squashable detects consecutive commits that touch the same
# file set and reports them as squashable candidates.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  helpers::set_git_identity
  SQUASHABLE="$REPO_ROOT/bash/find-squashable"

  # Build history designed to trigger "could be squashed" output:
  #   c0: add file_a.txt               (START_FROM — excluded from iteration)
  #   c1: add file_b.txt               (different file set → resets squash run)
  #   c2: modify file_a.txt            \
  #   c3: modify file_a.txt            |  three consecutive commits on file_a
  #   c4: modify file_a.txt            /
  # find-squashable iterates newest-first (c4, c3, c2, c1). When it reaches
  # c1 (file_b.txt ≠ file_a.txt) after the same-file run (c4/c3/c2), it
  # fires: "c4 to c2 could be squashed".
  FIXTURE_DIR=$(mktemp -d)
  (
    cd "$FIXTURE_DIR" || exit 1
    git init -q -b main .
    helpers::set_git_identity
    echo "initial" >file_a.txt
    git add file_a.txt
    git -c commit.gpgsign=false commit -q -m "feat: initial"
    touch file_b.txt
    git add file_b.txt
    git -c commit.gpgsign=false commit -q -m "feat: add file_b"
    echo "c1" >>file_a.txt
    git add file_a.txt
    git -c commit.gpgsign=false commit -q -m "feat: change file_a 1"
    echo "c2" >>file_a.txt
    git add file_a.txt
    git -c commit.gpgsign=false commit -q -m "feat: change file_a 2"
    echo "c3" >>file_a.txt
    git add file_a.txt
    git -c commit.gpgsign=false commit -q -m "feat: change file_a 3"
  )
  START_HASH=$(git -C "$FIXTURE_DIR" rev-list --reverse HEAD | head -1)
  export FIXTURE_DIR START_HASH SQUASHABLE
}

teardown() {
  rm -rf "$FIXTURE_DIR"
}

@test "find-squashable reports could be squashed for same-file consecutive commits" {
  run bash -c "cd '$FIXTURE_DIR' && '$SQUASHABLE' -s '$START_HASH'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"could be squashed"* ]]
}

# SUR-2840: when a same-files run extends to the oldest commit in the
# iteration range, the historical emit branch never fired because it
# required a different following commit. Build a history where every
# in-range commit touches the same file and assert the trailing group is
# still reported.
@test "find-squashable flushes a same-files group that extends to the last commit (SUR-2840)" {
  TAIL_FIXTURE=$(mktemp -d)
  (
    cd "$TAIL_FIXTURE" || exit 1
    git init -q -b main .
    helpers::set_git_identity
    echo "initial" >file_a.txt
    git add file_a.txt
    git -c commit.gpgsign=false commit -q -m "feat: initial"
    echo "c1" >>file_a.txt
    git add file_a.txt
    git -c commit.gpgsign=false commit -q -m "feat: change file_a 1"
    echo "c2" >>file_a.txt
    git add file_a.txt
    git -c commit.gpgsign=false commit -q -m "feat: change file_a 2"
    echo "c3" >>file_a.txt
    git add file_a.txt
    git -c commit.gpgsign=false commit -q -m "feat: change file_a 3"
  )
  TAIL_START=$(git -C "$TAIL_FIXTURE" rev-list --reverse HEAD | head -1)
  run bash -c "cd '$TAIL_FIXTURE' && '$SQUASHABLE' -s '$TAIL_START'"
  rm -rf "$TAIL_FIXTURE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"could be squashed"* ]]
}
