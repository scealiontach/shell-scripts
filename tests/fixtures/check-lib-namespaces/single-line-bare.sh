#!/usr/bin/env bash
# SUR-1937 fixture: a single-line bare function definition with a
# namespaced call inside its body. Pre-SUR-1937 the hook piped grep
# through `grep -v '::'`, which filtered the WHOLE line and silently
# dropped this case from the violation list. The hook now extracts
# the function-name token and tests *that* for `::`.
#
# shellcheck disable=SC2317  # unreachable: this is a fixture, never sourced.

function init() { log::info "starting"; }
