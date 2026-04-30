#!/usr/bin/env bash
# Fixture: true function-ending } after nested groups — must not leave hook stuck in-function.

outer() {
  {
    true
  }
  local ret
  ret=$?
  : "${ret}"
}
