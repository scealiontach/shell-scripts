#!/usr/bin/env bash
# Tiny assertion helpers used by tests/sur-*.sh
# shellcheck disable=SC2154

assert_eq() {
  local expected=$1
  local actual=$2
  local msg=${3:-"assert_eq"}
  if [ "$expected" != "$actual" ]; then
    echo "FAIL: $msg: expected [$expected] got [$actual]" >&2
    return 1
  fi
}

assert_neq() {
  local a=$1
  local b=$2
  local msg=${3:-"assert_neq"}
  if [ "$a" = "$b" ]; then
    echo "FAIL: $msg: expected [$a] != [$b]" >&2
    return 1
  fi
}

assert_zero() {
  local rc=$1
  local msg=${2:-"assert_zero"}
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: $msg: expected rc=0 got rc=$rc" >&2
    return 1
  fi
}

assert_nonzero() {
  local rc=$1
  local msg=${2:-"assert_nonzero"}
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: $msg: expected rc!=0 got rc=$rc" >&2
    return 1
  fi
}

assert_contains() {
  local haystack=$1
  local needle=$2
  local msg=${3:-"assert_contains"}
  case "$haystack" in
    *"$needle"*) ;;
    *)
      echo "FAIL: $msg: [$haystack] does not contain [$needle]" >&2
      return 1
      ;;
  esac
}

assert_no_var() {
  local var=$1
  local msg=${2:-"assert_no_var"}
  if declare -p "$var" >/dev/null 2>&1; then
    echo "FAIL: $msg: variable [$var] is set in caller scope" >&2
    return 1
  fi
}
