# shellcheck shell=bash disable=SC1091,SC2218
# SUR-2835 fixture: a function carrying `@doc` and `@arg` annotations.
# bashadoc must emit the doc text first, then an `### Arguments` block
# listing the @arg lines as a bullet list. The production script also
# translates `;` to ` ` to scrub the trailing semicolons that
# `declare -f` introduces at the end of every statement in the body.

source "$(dirname "${BASH_SOURCE[0]}")/../../../bash/includer.sh"
@include doc

@package annpkg

function annpkg::fn() {
  @doc One-line description of annpkg::fn.
  @arg _1_ first positional arg
  @arg -o "<arg>" the -o flag
  return 0
}
