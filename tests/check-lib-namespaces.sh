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

# Match: optional indentation, the literal `function ` keyword, then a
# bash identifier optionally containing `::` for namespaced names. The
# `function` keyword is the marker for new-style bash function
# definitions; the parens-only `foo()` form does not trip this check
# (see header). The `::` qualifier check happens at the function-name
# token level inside the loop below — pre-SUR-1937 the hook piped grep
# through `grep -v '::'`, which filtered the WHOLE line and silently
# dropped one-line definitions like `function init() { log::info ...;
# }` (bare name, namespaced call inside the body).
pattern='^[[:space:]]*function[[:space:]]+[a-zA-Z_][a-zA-Z0-9_:]*([[:space:]]*\(\))?[[:space:]]*(\{|$)'

rc=0
for f in "$@"; do
  case "$f" in
    # Accept both repo-relative paths (the form pre-commit always passes)
    # and absolute / nested paths so the regression script and ad-hoc
    # manual invocations exercise the same code path.
    bash/*.sh | */bash/*.sh) ;;
    *)
      # Warn (not silent) so a maintainer running the hook by hand on the
      # wrong file knows their invocation skipped it.
      echo "$0: skipped $f (only bash/<name>.sh inputs are checked)" >&2
      continue
      ;;
  esac
  while IFS= read -r line; do
    # grep -n output: "<linenum>:<body>". Strip the linenum prefix and
    # extract the function-name token (the identifier right after the
    # `function ` keyword) so the namespacing test runs against the
    # name only, not the whole line.
    body=${line#*:}
    fname=$(printf '%s\n' "$body" |
      sed -nE 's/^[[:space:]]*function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_:]*).*/\1/p')
    case "$fname" in
      '' | *::*) continue ;;
    esac
    rc=1
    printf '%s:%s\n' "$f" "$line" >&2
  done < <(grep -nE "$pattern" "$f" 2>/dev/null)
done

if [ "$rc" -ne 0 ]; then
  echo "" >&2
  echo "lib-funcs-must-be-namespaced: bash/*.sh libraries must use \`package::name\`" >&2
  echo "for any function defined with the \`function\` keyword. See AGENTS.md." >&2
fi
exit "$rc"
