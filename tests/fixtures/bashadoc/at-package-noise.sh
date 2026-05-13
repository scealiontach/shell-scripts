# shellcheck shell=bash disable=SC1091,SC2218
# SUR-2835 / SUR-2829 fixture: a library that defines a function named
# `@package` (mirroring the shape of `doc.sh`). The bashadoc
# `@package`-name extraction must not pick up `function @package() {`
# as a directive — the regression that produced `{` as the resolved
# "package name" and shipped garbage markdown.

source "$(dirname "${BASH_SOURCE[0]}")/../../../bash/includer.sh"
@include doc

function @package() {
  :
}
