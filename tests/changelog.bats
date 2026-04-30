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
