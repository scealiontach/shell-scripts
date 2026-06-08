#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  MAKE_BIN=$(asdf which make 2>/dev/null || command -v make)
  load 'helpers.bash'
  helpers::isolate_home
  PACKAGE_REPO=$(mktemp -d)
  cp -a "$REPO_ROOT"/. "$PACKAGE_REPO"/
  cd "$PACKAGE_REPO" || exit 1
}

teardown() {
  rm -rf "$PACKAGE_REPO"
}

@test "bin package includes standalone executable commands mddoc and semver (SUR-3353)" {
  run "$MAKE_BIN" clean package
  [ "$status" -eq 0 ]

  version=$("$MAKE_BIN" --no-print-directory what_version | awk -F= '/^VERSION=/{print $2}')
  tarball="$PACKAGE_REPO/dist/bin-$version.tar.gz"
  [ -f "$tarball" ]

  run tar -tzf "$tarball"
  [ "$status" -eq 0 ]
  [[ "$output" == *"bin/mddoc"* ]]
  [[ "$output" == *"bin/semver"* ]]
}
