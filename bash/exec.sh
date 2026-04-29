#!/usr/bin/env bash
# Copyright © 2023 Kevin T. O'Donnell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ------------------------------------------------------------------------------

# shellcheck source=includer.sh
source "$(dirname "${BASH_SOURCE[0]}")/includer.sh"

@include annotations
@include doc

@package exec

function exec::capture() {
  @doc Execute the provided command and capture the output to a log.
  @arg _1_ the command to execute
  @arg @ the arguments to the command
  local exit_code
  if [ -z "$LOGFILE_DISABLE" ] || [ "$LOGFILE_DISABLE" != "true" ]; then
    local logfile=${LOGFILE:-"exec.log"}
    local tmpout
    tmpout=$(mktemp)
    trap 'rm -f "$tmpout"' RETURN
    # Stream to caller stdout in real-time; second tee captures into tmpout.
    "$@" 2>&1 | tee -a "$logfile" | tee "$tmpout"
    exit_code=${PIPESTATUS[0]}
    # exec_output is an intentional output variable (no local) — callers read it.
    # shellcheck disable=SC2034
    exec_output=$(<"$tmpout")
  else
    # exec_output is an intentional output variable (no local) — callers read it.
    # shellcheck disable=SC2034
    exec_output=$("$@" 2>&1)
    exit_code=$?
    [[ -n "${exec_output}" ]] && printf '%s\n' "${exec_output}"
  fi
  return "${exit_code}"
}
exec_and_capture() {
  @doc Deprecated in favor of exec::capture
  deprecated exec::capture "$@"
}

function exec::hide() {
  @doc Execute the provided command and swallow the output
  "$@" >/dev/null 2>&1
}
exec_and_hide() {
  @doc Deprecated in favor of exec::hide
  deprecated exec::hide "$@"
}
