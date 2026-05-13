#!/usr/bin/env bats
# SUR-2829: bashadoc must anchor @package extraction. The previous
# `grep "@package"` matched `function @package() {` in doc.sh, yielding
# `{` as the "package" and shipping garbage markdown into doc-*.tar.gz.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  FIXTURE_DIR=$(mktemp -d)
  BASHADOC="$REPO_ROOT/bash/bashadoc"
}

teardown() {
  rm -rf "$FIXTURE_DIR"
}

@test "bashadoc renders a header from @package and lists pkg::* functions (SUR-2829)" {
  cat >"$FIXTURE_DIR/mypkg.sh" <<'EOF'
source "$(dirname "${BASH_SOURCE[0]}")/../bash/includer.sh"
@include doc

@package mypkg

function mypkg::fn() {
  @doc Does the thing.
  return 0
}
EOF
  out=$(bash "$BASHADOC" "$FIXTURE_DIR/mypkg.sh")
  [[ "$out" == *"# \`mypkg\` package"* ]]
  [[ "$out" == *"## \`mypkg::fn\`"* ]]
  [[ "$out" != *"\`{\`"* ]]
}

@test "bashadoc falls back to filename for libraries without @package (SUR-2829)" {
  cat >"$FIXTURE_DIR/nopkg.sh" <<'EOF'
function bare_fn() {
  return 0
}
EOF
  out=$(bash "$BASHADOC" "$FIXTURE_DIR/nopkg.sh")
  [[ "$out" == *"# $FIXTURE_DIR/nopkg.sh package"* ]]
  [[ "$out" == *"## \`bare_fn\`"* ]]
  [[ "$out" != *"\`{\`"* ]]
}

@test "bashadoc handles doc.sh (which defines function @package) without emitting '{' (SUR-2829)" {
  out=$(bash "$BASHADOC" "$REPO_ROOT/bash/doc.sh")
  [[ "$out" != *"\`{\`"* ]]
  [[ "$out" == *"package"* ]]
}
