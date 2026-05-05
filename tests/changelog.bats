#!/usr/bin/env bats
# SUR-1882: changelog emits section headers for tagged commit history;
# with -l, includes commit URLs when origin is a GitHub remote.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  helpers::set_git_identity
  CHANGELOG="$REPO_ROOT/bash/changelog"
  FIXTURE_DIR=$(mktemp -d)
  helpers::make_fixture_repo "$FIXTURE_DIR" --tagged
  # Add an untagged HEAD commit so git::tagsinhistory does not confuse the
  # HEAD decoration with a tag and emits clean v0.1.0/v0.2.0/v0.3.0 names.
  (
    cd "$FIXTURE_DIR" || exit 1
    echo "post" >>README
    git add README
    git -c commit.gpgsign=false commit -q -m "feat: post-tag change"
  )
  export FIXTURE_DIR CHANGELOG
}

teardown() {
  rm -rf "$FIXTURE_DIR"
}

@test "changelog exits 0 and emits CHANGELOG header" {
  run bash -c "cd '$FIXTURE_DIR' && '$CHANGELOG'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"# CHANGELOG"* ]]
}

@test "changelog emits v0.3.0 and v0.2.0 section headers" {
  run bash -c "cd '$FIXTURE_DIR' && '$CHANGELOG'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"## v0.3.0"* ]]
  [[ "$output" == *"## v0.2.0"* ]]
}

@test "changelog -l includes GitHub commit URLs when origin is a GitHub remote" {
  git -C "$FIXTURE_DIR" remote add origin "git@github.com:testorg/testrepo.git"
  run bash -c "cd '$FIXTURE_DIR' && '$CHANGELOG' -l"
  [ "$status" -eq 0 ]
  [[ "$output" == *"https://github.com/testorg/testrepo/commit"* ]]
}

# When every subject is filtered by `grep -v '^* ci'`, ::fromto still appends
# two blank lines; the section gate must not treat newline-only $body as content.
@test "changelog ::full skips section when all commits match ci filter" {
  local ci_only_fixture
  ci_only_fixture=$(mktemp -d)
  (
    cd "$ci_only_fixture" || exit 1
    git init -q -b main
    helpers::set_git_identity
    echo x >README
    git add README
    git -c commit.gpgsign=false commit -q -m "feat: bootstrap"
    git tag v0.1.0
    echo y >>README
    git add README
    git -c commit.gpgsign=false commit -q -m "ci: rubber stamp"
    echo z >>README
    git add README
    git -c commit.gpgsign=false commit -q -m "ci: another stamp"
  )
  run bash -c "cd '$ci_only_fixture' && '$CHANGELOG'"
  rm -rf "$ci_only_fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"# CHANGELOG"* ]]
  [[ "$output" != *"## "* ]]
}

# SUR-1939: ::full used to invoke ::fromto twice per tag iteration
# (once to count, once to print). The capture-once refactor must
# produce the same number of section headers AND emit the trailing
# blank-line separator that pre-fix `uniq` collapsed from ::fromto's
# two tail echoes — without that separator the regenerated
# CHANGELOG.md drops a trailing newline relative to the pre-fix
# output.
@test "changelog ::full output ends with a trailing blank line (SUR-1939)" {
  # $(...) would strip trailing newlines, so capture to a file and
  # let awk count the run of trailing empty lines directly.
  OUT_FILE=$(mktemp)
  (cd "$FIXTURE_DIR" && "$CHANGELOG") >"$OUT_FILE"
  trailing=$(awk 'BEGIN{n=0} {if($0==""){n++}else{n=0}} END{print n}' "$OUT_FILE")
  rm -f "$OUT_FILE"
  [ "$trailing" -eq 1 ]
}

# SUR-2327: -f and -t are documented as independent. Pre-fix, -f alone
# printed "No change history in the requested range" and -t alone hit
# ::fromto's `${1:?}` because from_commit was empty.
@test "changelog -f <past-date> alone produces a non-empty range up to HEAD (SUR-2327)" {
  run bash -c "cd '$FIXTURE_DIR' && '$CHANGELOG' -f 1970-01-01"
  [ "$status" -eq 0 ]
  [[ "$output" == *"feat: post-tag change"* ]]
  [[ "$output" != *"No change history in the requested range"* ]]
}

@test "changelog -t <future-date> alone produces a non-empty range from repo root (SUR-2327)" {
  # 2050-01-01 is the future-but-parseable upper bound for git's approxidate
  # parser. Pre-2026 we used 2999-01-01, but git rev-list's --before/--after
  # silently misparse 2999 and return wrong sets, masking the SUR-2327
  # follow-up bug ("flag passed but no match" must NOT silently expand).
  run bash -c "cd '$FIXTURE_DIR' && '$CHANGELOG' -t 2050-01-01"
  [ "$status" -eq 0 ]
  [[ "$output" == *"feat: post-tag change"* ]]
  [[ "$output" != *"No change history in the requested range"* ]]
}

@test "changelog -f and -t together produce a bounded range (SUR-2327)" {
  run bash -c "cd '$FIXTURE_DIR' && '$CHANGELOG' -f 1970-01-01 -t 2050-01-01"
  [ "$status" -eq 0 ]
  [[ "$output" == *"feat: post-tag change"* ]]
  [[ "$output" != *"No change history in the requested range"* ]]
}

# SUR-2327 follow-up: the SUR-2327 default-endpoint fix must not silently
# expand the range when the user passes -t with a date older than every
# commit. Pre-fix this branch defaulted to_commit=HEAD and dumped the
# full history — the opposite of what the user asked for.
@test "changelog -t <pre-history-date> reports no commits, not full history (SUR-2327)" {
  run bash -c "cd '$FIXTURE_DIR' && '$CHANGELOG' -t 1900-01-01"
  [ "$status" -eq 0 ]
  [[ "$output" != *"feat: initial"* ]]
  [[ "$output" != *"feat: second"* ]]
  [[ "$output" != *"feat: third"* ]]
  [[ "$output" != *"feat: post-tag change"* ]]
  [[ "$output" == *"No commits before 1900-01-01"* ]]
}

# SUR-2327 follow-up: same disambiguation for -f with a date after HEAD.
# Pre-fix this branch defaulted from_commit to the repo root and dumped
# the full history. 2050-01-01 chosen instead of 2999-01-01 because git
# rev-list's date parser silently misparses 2999 and would mask the bug.
@test "changelog -f <post-history-date> reports no commits, not full history (SUR-2327)" {
  run bash -c "cd '$FIXTURE_DIR' && '$CHANGELOG' -f 2050-01-01"
  [ "$status" -eq 0 ]
  [[ "$output" != *"feat: initial"* ]]
  [[ "$output" != *"feat: second"* ]]
  [[ "$output" != *"feat: third"* ]]
  [[ "$output" != *"feat: post-tag change"* ]]
  [[ "$output" == *"No commits on or after 2050-01-01"* ]]
}

# SUR-1939: count::fromto invocations to guarantee we don't run twice
# per tag iteration. We instrument by sourcing `bash/changelog`'s
# ::full + ::fromto definitions in a sub-shell that wraps ::fromto in
# a counting decorator backed by a marker file.
@test "changelog ::full invokes ::fromto exactly once per tag (SUR-1939)" {
  COUNT_FILE=$(mktemp)
  run bash -c "
    cd '$FIXTURE_DIR'
    source '$REPO_ROOT/bash/includer.sh'
    @include git
    @include options
    options::standard
    options::add -o l -d 'add hyperlinks to commits' -x ADD_LINKS
    options::add -o f -d 'from date' -a -e FROM_DATE
    options::add -o t -d 'to date' -a -e TO_DATE
    options::add -o d -d 'show commit date' -x SHOW_DATE
    export GIT_PAGER=cat
    eval \"\$(awk '/^function ::fromto\\(\\)/,/^}\$/' '$REPO_ROOT/bash/changelog')\"
    eval \"\$(awk '/^function ::full\\(\\)/,/^}\$/' '$REPO_ROOT/bash/changelog')\"
    real_fromto=\$(declare -f ::fromto)
    eval \"\${real_fromto/::fromto/::__real_fromto}\"
    ::fromto() {
      printf 'x' >> '$COUNT_FILE'
      ::__real_fromto \"\$@\"
    }
    ::full >/dev/null
  "
  [ "$status" -eq 0 ]
  fromto_calls=$(wc -c <"$COUNT_FILE" | tr -d ' ')
  rm -f "$COUNT_FILE"
  # The fixture has 3 tags in history and one post-tag HEAD commit,
  # so ::full must call ::fromto exactly 3 times. Pre-SUR-1939 it
  # called it twice as many: once to count, once to print.
  [ "$fromto_calls" -eq 3 ]
}
