#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  load 'helpers.bash'
  helpers::isolate_home
}

@test "bin package includes standalone executable commands mddoc and semver (SUR-3353)" {
  run make clean package
  [ "$status" -eq 0 ]

  version=$(make --no-print-directory what_version | awk -F= '/^VERSION=/{print $2}')
  tarball="$REPO_ROOT/dist/bin-$version.tar.gz"
  [ -f "$tarball" ]

  run tar -tzf "$tarball"
  [ "$status" -eq 0 ]
  [[ "$output" == *"bin/mddoc"* ]]
  [[ "$output" == *"bin/semver"* ]]
}
