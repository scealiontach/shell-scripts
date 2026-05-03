#!/usr/bin/env bats
# SUR-2178: release-images option and IMAGES_FILE loop behavior with
# SIMULATE / DRY_RUN. SUR-2173: blank and whitespace-only lines must
# not reach docker::pull / docker::cp.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  RELEASE_IMAGES="$REPO_ROOT/bash/release-images"
  export LOGFILE_DISABLE=true LOG_DISABLE_DEBUG=true LOG_DISABLE_INFO=true
}

@test "release-images -d sets SIMULATE so docker is not invoked" {
  imgf=$(mktemp)
  printf '%s\n' 'alpha/beta' >"$imgf"
  run env PATH="$REPO_ROOT/tests/stubs:$PATH" \
    DOCKER_ARGV_LOG=/dev/null \
    "$RELEASE_IMAGES" -d -t v1 -r reg.example -a other.example -f "$imgf"
  rm -f "$imgf"
  [ "$status" -eq 0 ]
  [[ "$output" == *"docker pull -q reg.example/alpha/beta:v1"* ]]
}

@test "release-images IMAGES_FILE skips comments, blanks, and whitespace-only lines (SUR-2173)" {
  imgf=$(mktemp)
  cat >"$imgf" <<'EOF'
# ignored header

gamma/delta




# tail comment
epsilon/zeta
EOF
  run env PATH="$REPO_ROOT/tests/stubs:$PATH" \
    DOCKER_ARGV_LOG=/dev/null \
    "$RELEASE_IMAGES" -d -t v1 -r reg.example -a other.example -f "$imgf"
  rm -f "$imgf"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Repository: gamma/delta"* ]]
  [[ "$output" == *"Repository: epsilon/zeta"* ]]
  [[ "$output" != *"reg.example/:v1"* ]]
  [[ "$output" != *"reg.example/ :v1"* ]]
  # First loop pulls each repo; second loop runs docker::cp which pulls again.
  pull_count=$(grep -c 'docker pull -q reg.example/' <<<"$output" || true)
  [[ "$pull_count" -eq 4 ]]
}

@test "release-images IMAGES_FILE runs docker::cp once per repo per additional registry" {
  imgf=$(mktemp)
  printf '%s\n' 'one/r' 'two/r' >"$imgf"
  run env PATH="$REPO_ROOT/tests/stubs:$PATH" \
    DOCKER_ARGV_LOG=/dev/null \
    "$RELEASE_IMAGES" -d -t t9 -r src.reg -a a.extra -f "$imgf"
  rm -f "$imgf"
  [ "$status" -eq 0 ]
  tag_count=$(grep -c 'docker tag src\.reg/' <<<"$output" || true)
  [[ "$tag_count" -eq 2 ]]
}
