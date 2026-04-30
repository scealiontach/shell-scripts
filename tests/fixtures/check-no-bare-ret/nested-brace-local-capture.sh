#!/usr/bin/env bash
# Fixture: same shape as nested-brace-bare-capture but local ret — hook must pass.

outer() {
  {
    true
  }
  local ret
  ret=$?
  : "${ret}"
}
