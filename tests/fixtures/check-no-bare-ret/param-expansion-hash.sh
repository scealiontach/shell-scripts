#!/usr/bin/env bash
# Fixture: '#' inside parameter expansion (${var#…} / ${var##…} / ${#var})
# must not be treated as a comment-start by the hook. If it were, the
# matching '}' would be skipped, fn_body_depth would drift, and the
# top-level `ret=$?` below would be wrongly flagged as inside the function.
#
# These expansions are intentionally *unquoted* so the parser sees the '#'
# in the bare `norm` state — the buggy code path. (Inside double-quotes,
# '#' is already skipped by the dq state and the bug does not trigger.)

strip_prefix() {
  local input=$1
  local stripped len
  stripped=${input#prefix-}
  stripped=${stripped##old/}
  len=${#input}
  echo "$stripped $len"
}

strip_prefix "$@"
ret=$?
exit "$ret"
