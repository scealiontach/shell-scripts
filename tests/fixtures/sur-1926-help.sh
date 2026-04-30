#!/usr/bin/env bash
# Fixture for SUR-1926: minimal command-style script that uses options::parse.
# When invoked with -h, the SYNTAX line of help output must show this
# fixture's basename, NOT options.sh.
#
# Note: this file lives under tests/fixtures/ and ends in .sh so the
# script-must-have-extension hook is satisfied via the tests/ exclusion
# (it's never executed via PATH; bats invokes it via `bash <path>`).

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../../bash/includer.sh"

@include options

options::standard
options::add -o n -d "name" -a -e Name
options::parse "$@"
