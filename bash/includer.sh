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

# shellcheck source=doc.sh
source "$(dirname "${BASH_SOURCE[0]}")/doc.sh"

@package includer

function @include {
  local include_file=${1:?}
  local true_file
  true_file="$(dirname "${BASH_SOURCE[0]}")/$include_file"
  [ ! -r "$true_file" ] && true_file="$true_file.sh"
  if [ -r "$true_file" ]; then
    local file_cksum
    file_cksum=$(cksum "$true_file" | awk '{print $1}')
    local src_name=include_${file_cksum}
    if [ -z "${!src_name}" ]; then
      declare -g "$src_name=${src_name}"
      # shellcheck disable=SC1090
      source "$true_file"
    fi
  else
    echo "Cannot find include file $true_file" >&2
    return 1
  fi
}

function includer::find {
  @doc Find the file referred to as an include.
  @arg _1_ the name of the include
  local include_file=${1:?}
  local true_file
  true_file="$(dirname "${BASH_SOURCE[0]}")/$include_file"
  [ ! -r "$true_file" ] && true_file="$true_file.sh"
  if [ -r "$true_file" ]; then
    echo "$true_file"
  else
    return 1
  fi
}
