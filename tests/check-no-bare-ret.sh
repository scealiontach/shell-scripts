#!/usr/bin/env bash
# check-no-bare-ret.sh — pre-commit hook (SUR-1874)
#
# Flags bare variable captures of $? (ret=$?, exit_code=$?, exit_status=$?,
# rc=$?) inside shell functions where the variable was not declared `local`
# earlier in the same function body.
#
# Prevents the SUR-1874 anti-pattern (bare exit-code capture that leaks the
# variable into the caller's scope) from being re-introduced. Individual
# fixes were applied in SUR-1859, SUR-1860, SUR-1868, SUR-1871, and SUR-1883;
# this hook makes future violations impossible without a deliberate bypass.
#
# Usage: check-no-bare-ret.sh [files...]
#
# Exit codes:
#   0 — no offending lines found
#   1 — at least one bare capture found (printed to stderr)
#   2 — invocation error (no files passed)

set -u

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <file>..." >&2
  exit 2
fi

# Regex: a line that assigns $? to a tracked variable name (bare or local).
# Used to spot any capture; we then check whether a local precedes it.
CAPTURE_PAT='^[[:space:]]*(ret|exit_code|exit_status|rc)=[[:space:]]*[$][?]'

# Regex: line begins with `local` (possibly indented).
LOCAL_LINE_PAT='^[[:space:]]*local[[:space:]]'

# Regex: function definition line — either:
#   function name         (no parens, brace on same or next line)
#   function name()       (parens, brace on same or next line)
#   name()                (POSIX parens style)
FUNC_DEF_PAT='^[[:space:]]*(function[[:space:]]+[a-zA-Z_][a-zA-Z0-9_:]*|[a-zA-Z_][a-zA-Z0-9_:]*[[:space:]]*[(][)])'

found=0

for file in "$@"; do
  in_function=0
  locals=""

  while IFS= read -r line; do
    # Detect function entry.
    if [[ "$line" =~ $FUNC_DEF_PAT ]]; then
      in_function=1
      locals=""
      continue
    fi

    # Detect function end: a lone `}` (possibly indented) on its own line.
    if [[ "$line" =~ ^[[:space:]]*[}][[:space:]]*$ ]] && [ "$in_function" -eq 1 ]; then
      in_function=0
      locals=""
      continue
    fi

    [ "$in_function" -eq 0 ] && continue

    # Record `local` declarations for tracked variable names.
    if [[ "$line" =~ $LOCAL_LINE_PAT ]]; then
      for varname in ret exit_code exit_status rc; do
        # Match `local varname`, `local varname=...`, or `local a varname b`.
        if [[ "$line" =~ (^|[[:space:]])local([[:space:]]+-[a-zA-Z])*[[:space:]]${varname}([[:space:]]|=|$) ]] ||
          [[ "$line" =~ (^|[[:space:]])local([[:space:]]+-[a-zA-Z])*[[:space:]].*[[:space:]]${varname}([[:space:]]|=|$) ]]; then
          locals="$locals $varname "
        fi
      done
      continue
    fi

    # Check for a bare capture on this line.
    if [[ "$line" =~ $CAPTURE_PAT ]]; then
      varname="${BASH_REMATCH[1]}"
      if [[ " $locals " != *" $varname "* ]]; then
        echo "$file: bare capture (add 'local $varname'): $line" >&2
        found=1
      fi
    fi
  done <"$file"

done

if [ "$found" -ne 0 ]; then
  echo "" >&2
  echo "check-no-bare-ret: add 'local' before \$? captures. See SUR-1874." >&2
fi
exit "$found"
