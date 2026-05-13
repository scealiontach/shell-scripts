# shellcheck shell=bash
# SUR-2835 fixture: a library with no `@package` directive. bashadoc
# must fall back to using the file path as the title and list only
# bare-name functions (no `pkg::` prefix).

function bare_fn() {
  return 0
}
