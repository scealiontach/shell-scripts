#!/usr/bin/env bash
# Fixture: simple function, bare capture (regression / baseline failure path).

f() {
  ret=$?
  : "${ret}"
}
