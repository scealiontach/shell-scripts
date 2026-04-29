#!/usr/bin/env bash
# Fixture for SUR-1840 / lib-funcs-must-be-namespaced lint regression.
# This file deliberately defines a bare `function foo()` so that
# tests/check-lib-namespaces.sh can confirm the lint fires. It must NOT
# be sourced as a real library.
#
# shellcheck disable=SC2317  # unreachable: this is a fixture, never sourced.

# SHELLCHECK doesn't run on this file because the pre-commit `shellcheck`
# hook only walks scripts matched by the file-pattern checker; we leave
# the directive above for editor integrations that scan everything.

function bare_offender() {
  echo "this should trip the lint"
}

function bare_namespaced::ok() {
  echo "this is fine"
}
