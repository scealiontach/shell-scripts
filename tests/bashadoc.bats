#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# SUR-2835: bashadoc has direct coverage for the five contract points
# called out in the issue:
#   1. `@package` header rendering.
#   2. No-`@package` fallback to filename + bare-name functions.
#   3. `@doc` + `@arg` ordering with semicolon stripping in @doc.
#   4. `function @package() {` non-pollution regression (SUR-2829).
#   5. Non-`.sh` argument fails with exit 1 and the documented stderr.
#
# Fixtures live under tests/fixtures/bashadoc/ rather than heredoc'd
# inline so each case can be inspected directly.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  BASHADOC="$REPO_ROOT/bash/bashadoc"
  FIXTURES="$REPO_ROOT/tests/fixtures/bashadoc"
}

@test "bashadoc renders @package header and namespaced functions (SUR-2835 case 1)" {
  out=$(bash "$BASHADOC" "$FIXTURES/with-package.sh")
  [[ "$out" == *"# \`mypkg\` package"* ]]
  [[ "$out" == *"## \`mypkg::fn\`"* ]]
  [[ "$out" != *"\`{\`"* ]]
}

@test "bashadoc falls back to filename when @package is missing (SUR-2835 case 2)" {
  out=$(bash "$BASHADOC" "$FIXTURES/no-package.sh")
  [[ "$out" == *"# $FIXTURES/no-package.sh package"* ]]
  [[ "$out" == *"## \`bare_fn\`"* ]]
  [[ "$out" != *"::"* ]]
}

@test "bashadoc renders @doc then @arg with semicolons stripped (SUR-2835 case 3)" {
  out=$(bash "$BASHADOC" "$FIXTURES/annotations.sh")
  [[ "$out" == *"## \`annpkg::fn\`"* ]]
  # The doc body renders verbatim, with no trailing semicolon (the
  # production script runs `tr ';' ' '` over the captured @doc/@arg
  # text to strip the semicolons that `declare -f` inserts at the end
  # of every statement in the function body).
  [[ "$out" == *"One-line description of annpkg::fn."* ]]
  # @arg lines appear under an `### Arguments` heading, as bullets, and
  # carry no trailing semicolon from declare -f.
  [[ "$out" == *"### Arguments"* ]]
  [[ "$out" == *"- _1_ first positional arg"* ]]
  [[ "$out" == *"- -o \"<arg>\" the -o flag"* ]]
  [[ "$out" != *"first positional arg;"* ]]
  [[ "$out" != *"the -o flag;"* ]]
  # Doc body comes before the Arguments section.
  doc_line=$(printf '%s\n' "$out" | grep -n "One-line description" | head -1 | cut -d: -f1)
  args_line=$(printf '%s\n' "$out" | grep -n "### Arguments" | head -1 | cut -d: -f1)
  [ "$doc_line" -lt "$args_line" ]
}

@test "bashadoc ignores 'function @package() {' as a directive (SUR-2835 case 4)" {
  out=$(bash "$BASHADOC" "$FIXTURES/at-package-noise.sh")
  # The previous unanchored grep produced a title of "`{` package";
  # the anchored awk extracts no directive, so the fallback file-path
  # title is used instead.
  [[ "$out" != *"\`{\`"* ]]
  [[ "$out" == *"# $FIXTURES/at-package-noise.sh package"* ]]
}

@test "bashadoc rejects non-.sh argument with exit 1 (SUR-2835 case 5)" {
  run bash "$BASHADOC" "$FIXTURES/not-a-shell-file.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"expected a .sh file"* ]]
}

@test "bashadoc handles doc.sh (defines function @package) without emitting '{' (SUR-2829)" {
  out=$(bash "$BASHADOC" "$REPO_ROOT/bash/doc.sh")
  [[ "$out" != *"\`{\`"* ]]
  [[ "$out" == *"package"* ]]
}
