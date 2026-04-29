#!/usr/bin/env bash
# Lint hook for the `lib-funcs-must-be-namespaced` pre-commit check
# (SUR-1840).
#
# Fails if any line in a passed bash/*.sh file defines a bare function via
# the `function` keyword without a `package::name` qualifier. The
# parens-only form (`foo() { ... }`) is intentionally left alone because
# AGENTS.md still allows it for backward-compat shims that delegate via
# `deprecated namespaced::name "$@"`.
#
# Usage: check-lib-namespaces.sh <file> [<file>...]
#
# Exit codes:
#   0 — no offending definitions found
#   1 — at least one offender found (printed to stderr in `path:line:body`
#       form)
#   2 — invocation error (no files passed)

set -u

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <bash/*.sh file>..." >&2
  exit 2
fi

# Match: optional indentation, the literal `function ` keyword, an
# identifier that does NOT contain `::`, then either `()` or `{` or
# end-of-line. The `function` keyword is the marker for new-style bash
# function definitions; the parens-only `foo()` form does not trip this
# check (see header).
pattern='^[[:space:]]*function[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*([[:space:]]*\(\))?[[:space:]]*(\{|$)'

rc=0
for f in "$@"; do
  case "$f" in
    bash/*.sh) ;;
    *)
      # Pre-commit's `files` regex already restricts inputs to bash/*.sh,
      # but skip silently if a caller invokes the hook directly on
      # something else.
      continue
      ;;
  esac
  while IFS= read -r line; do
    rc=1
    printf '%s\n' "$line" >&2
  done < <(grep -nE "$pattern" "$f" 2>/dev/null | grep -v '::')
done

if [ "$rc" -ne 0 ]; then
  echo "" >&2
  echo "lib-funcs-must-be-namespaced: bash/*.sh libraries must use \`package::name\`" >&2
  echo "for any function defined with the \`function\` keyword. See AGENTS.md." >&2
fi
exit "$rc"
