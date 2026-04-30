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
# this hook catches typical violations without requiring shellcheck-level
# parsing. Brace depth is tracked so a closing `}` from an inner `{ ... }`
# group does not end function scope (SUR-1936); `{`/`}` inside comments and
# basic quoted spans are skipped. `#` is only treated as a comment marker
# at start-of-token so parameter expansions like `${var#…}` and `${#var}`
# do not abort line parsing. Heredocs and `$'…'` ANSI-C quoting are not
# fully tracked — a pre-existing limitation.
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

# Update fn_body_depth / fn_body_pending from one line of source (comment and
# simple quote rules only). Uses globals: fn_body_depth, fn_body_pending.
apply_line_braces() {
  local line=$1
  local i len c state
  len=${#line}
  i=0
  state=norm
  while ((i < len)); do
    c=${line:i:1}
    case "$state" in
      norm)
        case "$c" in
          '#')
            # '#' starts a comment only at start-of-token (start of line
            # or after whitespace). Inside ${var#…} / ${var##…} / ${#var}
            # the '#' is part of parameter expansion; aborting here would
            # leave the matching '}' unmatched and drift fn_body_depth.
            if ((i == 0)) || [[ ${line:i-1:1} =~ [[:space:]] ]]; then
              break
            fi
            ;;
          "'")
            state=sq
            ;;
          '"')
            state=dq
            ;;
          '{')
            if [ "$fn_body_pending" -eq 1 ]; then
              fn_body_pending=0
            fi
            fn_body_depth=$((fn_body_depth + 1))
            ;;
          '}')
            if [ "$fn_body_pending" -eq 0 ]; then
              fn_body_depth=$((fn_body_depth - 1))
              if [ "$fn_body_depth" -lt 0 ]; then
                fn_body_depth=0
              fi
            fi
            ;;
        esac
        ;;
      sq)
        if [ "$c" = "'" ]; then
          state=norm
        fi
        ;;
      dq)
        case "$c" in
          $'\\')
            if ((i + 1 < len)); then
              ((i++))
            fi
            ;;
          '"')
            state=norm
            ;;
        esac
        ;;
    esac
    ((i++))
  done
}

found=0

for file in "$@"; do
  in_function=0
  locals=""
  fn_body_pending=0
  fn_body_depth=0

  while IFS= read -r line; do
    if [[ "$line" =~ $FUNC_DEF_PAT ]]; then
      in_function=1
      locals=""
      fn_body_pending=1
      fn_body_depth=0
      apply_line_braces "$line"
      if [ "$fn_body_pending" -eq 0 ] && [ "$fn_body_depth" -eq 0 ]; then
        in_function=0
        locals=""
      fi
      continue
    fi

    [ "$in_function" -eq 0 ] && continue

    if [[ "$line" =~ $LOCAL_LINE_PAT ]]; then
      for varname in ret exit_code exit_status rc; do
        if [[ "$line" =~ (^|[[:space:]])local([[:space:]]+-[a-zA-Z])*[[:space:]]${varname}([[:space:]]|=|$) ]] ||
          [[ "$line" =~ (^|[[:space:]])local([[:space:]]+-[a-zA-Z])*[[:space:]].*[[:space:]]${varname}([[:space:]]|=|$) ]]; then
          locals="$locals $varname "
        fi
      done
      apply_line_braces "$line"
      if [ "$fn_body_pending" -eq 0 ] && [ "$fn_body_depth" -eq 0 ]; then
        in_function=0
        locals=""
      fi
      continue
    fi

    if [[ "$line" =~ $CAPTURE_PAT ]]; then
      varname="${BASH_REMATCH[1]}"
      if [[ " $locals " != *" $varname "* ]]; then
        echo "$file: bare capture (add 'local $varname'): $line" >&2
        found=1
      fi
    fi

    apply_line_braces "$line"
    if [ "$fn_body_pending" -eq 0 ] && [ "$fn_body_depth" -eq 0 ]; then
      in_function=0
      locals=""
    fi
  done <"$file"

done

if [ "$found" -ne 0 ]; then
  echo "" >&2
  echo "check-no-bare-ret: add 'local' before \$? captures. See SUR-1874." >&2
fi
exit "$found"
