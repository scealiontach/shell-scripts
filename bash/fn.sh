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

@package fn

function fn::if_exists() {
  @doc if the named function exists with the specified argument execute it \
    otherwise return
  local func=$1
  shift
  local _type
  _type="$(type -t "$func")"
  if [ -n "$_type" ]; then
    $func "$@"
  fi
}
fn_if_exists() {
  @doc "Deprecated in favor of fn::if_exists"
  deprecated fn::if_exists "$@"
}

function fn::wrapped() {
  @doc Call/wrap the named function. The wrapper is expected to execute the \
    the wrapped function
  local wrapper=$1
  shift
  local _type
  _type="$(type -t "$wrapper")"
  if [ -n "$_type" ]; then
    $wrapper "$@"
  else
    "$@"
  fi
}
fn_wrapped() {
  @doc Deprecated in favor of fn::wrapped
  deprecated fn::wrapped "$@"
}
