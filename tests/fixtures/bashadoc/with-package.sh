# shellcheck shell=bash disable=SC1091,SC2218
# SUR-2835 fixture: a library that declares `@package` and one
# namespaced function. The bashadoc header must read `# `mypkg` package`
# and the function section must list `mypkg::fn` (and only that).

source "$(dirname "${BASH_SOURCE[0]}")/../../../bash/includer.sh"
@include doc

@package mypkg

function mypkg::fn() {
  @doc Does the thing.
  return 0
}
