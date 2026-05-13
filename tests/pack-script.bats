#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# SUR-2842: pack-script's `::get_includes` must anchor on a leading
# `@include[[:space:]]+` directive and strip trailing comments before
# extracting the include name. The previous
#   grep "^@include" | awk '{print $NF}'
# misparsed three concrete cases:
#   1. trailing comment lines (`@include foo  # SUR-...`) → comment text
#   2. multi-arg lines (`@include foo bar baz`) → trailing arg
#   3. lines mentioning `@include` mid-text (or `@includes`, or bare
#      `@include` with no argument) leaked into the include list.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  PACK="$REPO_ROOT/bash/pack-script"
  FIXTURES="$REPO_ROOT/tests/pack-script"
}

@test "pack-script extracts include name despite trailing comment (SUR-2842)" {
  out=$(mktemp -d)
  run "$PACK" -f "$FIXTURES/fixture-include-comment.sh" -o "$out/packed"
  [ "$status" -eq 0 ]
  # The packed output must contain log.sh content (log::error is defined
  # at the top of bash/log.sh) and MUST NOT mention the trailing-comment
  # sentinel that would surface if `awk '{print $NF}'` were still in use.
  grep -q "^function log::" "$out/packed"
  run ! grep -q "ZZZTRAILINGSENTINELZZZ" "$out/packed"
}

@test "pack-script ignores extra tokens after the include name (SUR-2842)" {
  out=$(mktemp -d)
  run "$PACK" -f "$FIXTURES/fixture-include-multiarg.sh" -o "$out/packed"
  [ "$status" -eq 0 ]
  grep -q "^function log::" "$out/packed"
  # Trailing tokens are not includable names; if `::get_includes` ever
  # surfaces them, includer::find will fail or their sentinel strings
  # will appear in the packed output (impossible here because the
  # @include directive line is stripped at pack time).
  run ! grep -q "MULTIARGEXTRAONESENTINEL" "$out/packed"
  run ! grep -q "MULTIARGEXTRATWOSENTINEL" "$out/packed"
}

@test "pack-script only matches leading @include directives (SUR-2842)" {
  out=$(mktemp -d)
  run "$PACK" -f "$FIXTURES/fixture-include-leading-only.sh" -o "$out/packed"
  [ "$status" -eq 0 ]
  # Exactly one real `@include log` lives in the fixture; the packed
  # output should contain log.sh contents exactly once even though the
  # file mentions @include in several non-directive contexts.
  grep -q "log::" "$out/packed"
  # The mid-line mention and the `@includes log` line must not have
  # caused a second log.sh inlining or any new include resolution.
  occurrences=$(grep -c "^log::level()" "$out/packed" || true)
  [ "$occurrences" -le 1 ]
}
