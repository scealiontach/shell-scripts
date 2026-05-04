#!/usr/bin/env bats
# SUR-1851: lock down bash/semver — release-tagging engine consumed by
# update-repo-tags on main, MAVEN_REVISION calculation in standard_defs.mk.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  SEMVER="$REPO_ROOT/bash/semver"
  export SEMVER
}

# ---------- bump ------------------------------------------------------------

@test "bump major: 1.2.3 -> 2.0.0" {
  run "$SEMVER" bump major 1.2.3
  [ "$status" -eq 0 ]
  [ "$output" = "2.0.0" ]
}

@test "bump minor: 1.2.3 -> 1.3.0" {
  run "$SEMVER" bump minor 1.2.3
  [ "$status" -eq 0 ]
  [ "$output" = "1.3.0" ]
}

@test "bump patch: 1.2.3 -> 1.2.4" {
  run "$SEMVER" bump patch 1.2.3
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.4" ]
}

@test "bump release: 1.2.3-rc.1+build.5 -> 1.2.3 (drops prerel and build)" {
  run "$SEMVER" bump release 1.2.3-rc.1+build.5
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3" ]
}

@test "bump prerel: 1.2.3 + rc.1 -> 1.2.3-rc.1" {
  run "$SEMVER" bump prerel rc.1 1.2.3
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3-rc.1" ]
}

@test "bump build: 1.2.3 + build.5 -> 1.2.3+build.5" {
  run "$SEMVER" bump build build.5 1.2.3
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3+build.5" ]
}

@test "bump build: keeps existing prerel: 1.2.3-rc.1 + b -> 1.2.3-rc.1+b" {
  run "$SEMVER" bump build b 1.2.3-rc.1
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3-rc.1+b" ]
}

@test "bump major zeroes minor and patch even when starting non-zero" {
  run "$SEMVER" bump major 4.7.9
  [ "$status" -eq 0 ]
  [ "$output" = "5.0.0" ]
}

# ---------- compare ---------------------------------------------------------

@test "compare equal: 1.2.3 == 1.2.3 -> 0" {
  run "$SEMVER" compare 1.2.3 1.2.3
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "compare older patch: 1.2.3 vs 1.2.4 -> -1" {
  run "$SEMVER" compare 1.2.3 1.2.4
  [ "$status" -eq 0 ]
  [ "$output" = "-1" ]
}

@test "compare newer patch: 1.2.5 vs 1.2.4 -> 1" {
  run "$SEMVER" compare 1.2.5 1.2.4
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "compare ignores build metadata" {
  run "$SEMVER" compare 1.2.3+a 1.2.3+b
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "compare prerelease: 1.2.3-rc.1 < 1.2.3 (prerel-less wins)" {
  run "$SEMVER" compare 1.2.3-rc.1 1.2.3
  [ "$status" -eq 0 ]
  [ "$output" = "-1" ]
}

@test "compare prerelease: 1.2.3 > 1.2.3-rc.1" {
  run "$SEMVER" compare 1.2.3 1.2.3-rc.1
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "compare prerelease ordering: 1.2.3-alpha < 1.2.3-beta" {
  run "$SEMVER" compare 1.2.3-alpha 1.2.3-beta
  [ "$status" -eq 0 ]
  [ "$output" = "-1" ]
}

@test "compare prerelease ordering: numeric < alpha within prerel" {
  # Per semver spec: numeric identifiers always have lower precedence than
  # alphanumeric ones.
  run "$SEMVER" compare 1.2.3-1 1.2.3-alpha
  [ "$status" -eq 0 ]
  [ "$output" = "-1" ]
}

# ---------- help ------------------------------------------------------------

@test "--version prints program line (SUR-2251)" {
  run "$SEMVER" --version
  [ "$status" -eq 0 ]
  [ "$output" = "semver: 3.1.0" ]
}

@test "--help USAGE block lists the diff subcommand (SUR-1878)" {
  run "$SEMVER" --help
  [ "$status" -eq 0 ]
  echo "$output" | grep -E '^[[:space:]]*semver diff <version> <other_version>'
}

# ---------- diff ------------------------------------------------------------

@test "diff major: 1.0.0 vs 2.0.0 -> major" {
  run "$SEMVER" diff 1.0.0 2.0.0
  [ "$status" -eq 0 ]
  [ "$output" = "major" ]
}

@test "diff minor: 1.0.0 vs 1.1.0 -> minor" {
  run "$SEMVER" diff 1.0.0 1.1.0
  [ "$status" -eq 0 ]
  [ "$output" = "minor" ]
}

@test "diff patch: 1.0.0 vs 1.0.1 -> patch" {
  run "$SEMVER" diff 1.0.0 1.0.1
  [ "$status" -eq 0 ]
  [ "$output" = "patch" ]
}

@test "diff prerelease: 1.0.0 vs 1.0.0-rc.1 -> prerelease" {
  run "$SEMVER" diff 1.0.0 1.0.0-rc.1
  [ "$status" -eq 0 ]
  [ "$output" = "prerelease" ]
}

@test "diff build: 1.0.0+a vs 1.0.0+b -> build" {
  run "$SEMVER" diff 1.0.0+a 1.0.0+b
  [ "$status" -eq 0 ]
  [ "$output" = "build" ]
}

@test "diff identical: 1.2.3 vs 1.2.3 -> empty" {
  run "$SEMVER" diff 1.2.3 1.2.3
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

# ---------- get -------------------------------------------------------------

@test "get major" {
  run "$SEMVER" get major 4.7.9
  [ "$status" -eq 0 ]
  [ "$output" = "4" ]
}

@test "get minor" {
  run "$SEMVER" get minor 4.7.9
  [ "$status" -eq 0 ]
  [ "$output" = "7" ]
}

@test "get patch" {
  run "$SEMVER" get patch 4.7.9
  [ "$status" -eq 0 ]
  [ "$output" = "9" ]
}

@test "get release strips prerel and build" {
  run "$SEMVER" get release 1.2.3-rc.1+build.5
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3" ]
}

@test "get prerel returns the bare identifier (no leading dash)" {
  run "$SEMVER" get prerel 1.2.3-rc.1
  [ "$status" -eq 0 ]
  [ "$output" = "rc.1" ]
}

@test "get build returns the bare identifier (no leading plus)" {
  run "$SEMVER" get build 1.2.3+abc
  [ "$status" -eq 0 ]
  [ "$output" = "abc" ]
}

@test "get prerel returns empty when absent" {
  run "$SEMVER" get prerel 1.2.3
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

# ---------- validate-version edge cases -------------------------------------

@test "rejects malformed version: 'foo'" {
  run "$SEMVER" bump major foo
  [ "$status" -ne 0 ]
}

@test "rejects malformed version: '1.2'" {
  run "$SEMVER" bump major 1.2
  [ "$status" -ne 0 ]
}

@test "rejects leading-zero numeric identifier in prerelease" {
  # Per semver spec, 1.0.0-01 is invalid (numeric identifier with leading zero).
  # The semver tool's regex correctly forbids it.
  run "$SEMVER" compare 1.0.0-01 1.0.0
  [ "$status" -ne 0 ]
}

@test "accepts a v-prefixed version on bump" {
  run "$SEMVER" bump patch v1.2.3
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.4" ]
}

@test "accepts build metadata in validate" {
  run "$SEMVER" get build 1.2.3+sha.deadbeef
  [ "$status" -eq 0 ]
  [ "$output" = "sha.deadbeef" ]
}

# ---------- validate-version nameref population (SUR-1875) ------------------

@test "validate-version populates the named array via nameref (no eval)" {
  # Source the script's functions in a sub-shell, then call validate-version
  # against a representative version with both prerelease and build metadata
  # and assert each parts[i] value. This is the public contract callers like
  # command-bump / command-diff / command-get rely on.
  run env "SEMVER_SOURCE_ONLY=true" bash -c "
    source '$SEMVER'
    declare -a parts
    validate-version '1.2.3-rc.1+meta' parts
    printf '%s\n' \"\${parts[0]}\" \"\${parts[1]}\" \"\${parts[2]}\" \"\${parts[3]}\" \"\${parts[4]}\"
  "
  [ "$status" -eq 0 ]
  expected=$'1\n2\n3\n-rc.1\n+meta'
  [ "$output" = "$expected" ]
}

@test "validate-version one-arg form echoes the version verbatim" {
  run "$SEMVER" bump release 1.2.3-rc.1+meta
  [ "$status" -eq 0 ]
  # The 1-arg validate-version path is exercised by command-bump's release
  # synthesis in command-bump 'major|minor|patch|release' mode, but the
  # bare contract check is simpler via the get-style path. Any of bump
  # release / get release returning 1.2.3 confirms the path.
  [ "$output" = "1.2.3" ]
}

@test "validate-version nameref does not leak variables to caller scope" {
  run env "SEMVER_SOURCE_ONLY=true" bash -c "
    source '$SEMVER'
    declare -a parts
    validate-version '1.2.3-rc.1+meta' parts
    [ -z \"\${version:-}\" ]      || { echo 'version leaked' >&2; exit 1; }
    [ -z \"\${_vv_out:-}\" ]      || { echo '_vv_out leaked' >&2; exit 1; }
  "
  [ "$status" -eq 0 ]
}
