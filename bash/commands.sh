#!/usr/bin/env bash
# Copyright © 2023 Kevin T. O'Donnell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ------------------------------------------------------------------------------

# shellcheck source=includer.sh
source "$(dirname "${BASH_SOURCE[0]}")/includer.sh"

@include doc
@include log

@package commands

function commands::err_not_found {
  @doc Print command not found error message and exit
  @arg _1_ the command that was not found
  local cmd=${1:?}
  log::error "$cmd is either not installed or not on the PATH"
  exit 1
}

function commands::use {
  @doc Find the specified command on the PATH if available or error
  @arg _1_ the base command name to find
  local cmd=${1:?}
  # Cache-key sanitisation: bash variable names cannot contain hyphens or
  # dots, so commands like ssh-keygen or python3.12 must be remapped to
  # _ssh_keygen / _python3_12 for the declare -g call. The lookup itself
  # below keeps the original $cmd. Distinct names that collide after
  # sanitisation (foo-bar vs foo_bar) would share a cache slot, but that
  # is vanishingly unlikely on a real PATH.
  local var=_${cmd//[^A-Za-z0-9_]/_}
  if [ -z "${!var}" ]; then
    local cmd_path
    cmd_path=$(command -v "$cmd") || commands::err_not_found "$cmd"
    declare -g "${var}=$cmd_path"
  fi
  echo "${!var}"
  return
}
