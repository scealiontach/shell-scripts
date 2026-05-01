#!/usr/bin/env bash
# Fixture: nested { } inside a function; bare ret=$? after inner } must be flagged (SUR-1936).

outer() {
  {
    true
  }
  ret=$?
  : "${ret}"
}
