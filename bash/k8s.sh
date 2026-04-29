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
@include commands
@include doc
@include fn
@include log

@package k8s

function k8s::ctl() {
  @doc Smart commnad kubectl
  log::trace "fn::wrapped exec::capture $(commands::use kubectl) $*"
  fn::wrapped exec::capture "$(commands::use kubectl)" "$@"
}

function k8s::exec() {
  @doc On pod "$1" in container "$2" execute the command provided
  local pod="${1:?}"
  local container="${2:?}"
  shift 2
  k8s::ctl exec "$pod" -c "$container" "$@"
}
kexec() {
  @doc deprecated in favor k8s::exec
  deprecated k8s::exec "$@"
}

function k8s::log() {
  @doc Get the logs
  k8s::ctl logs "$@"
}
klog() {
  @doc "deprecated in favor of k8s::log"
  deprecated k8s::log "$@"
}

function k8s::cp() {
  @doc Copy the named file to/from a k8s pod/container
  k8s::ctl cp "$@"
}
kcp() {
  @doc deprecated in favor of k8s::cp
  deprecated k8s::cp "$@"
}

function k8s::get() {
  @doc get k8s resources
  k8s::ctl get "$@"
}

function k8s::get_pod_names() {
  @doc get the list of pod names
  k8s::get pods -o name "$@"
}

function k8s::pod_names_for_label() {
  @doc List short pod names matching a label, restricted to Running phase
  @arg _1_ the label selector passed verbatim to kubectl as -l
  @arg _2_ optional namespace, empty for the active context
  local label=${1:?label selector required}
  local ns=${2:-}
  local args=(pods -l "$label" --field-selector=status.phase=Running -o name)
  [ -n "$ns" ] && args+=(-n "$ns")
  # shellcheck disable=SC2016 # $2 is awk's positional, not a shell expansion
  k8s::get "${args[@]}" | $(commands::use awk) -F/ '{print $2}'
}

function k8s::get_ns() {
  @doc get the list of pod names
  for ns in $(k8s::get ns -o name "$@"); do
    echo "${ns//namespace\//}"
  done
}

function k8s::get_containers_for_pod() {
  @doc get the list of container names for this pod
  local pod=${1:?}
  local ns=${2:?}
  pod=${pod//pod\//}
  k8s::get pod -n "$ns" "${pod}" -o json | $(commands::use jq) \
    -r '.spec.containers[].name'
}

function k8s::config() {
  @doc Smart command kubectl config
  k8s::ctl config "$@"
}

function k8s::describe() {
  @doc Smart command kubectl describe
  k8s::ctl describe "$@"
}

function k8s::current_ns() {
  @doc Get the currently selected namespace
  k8s::config view --minify --output 'jsonpath={..namespace}'
}

function k8s::current_cluster() {
  @doc Get the currently selected cluster
  k8s::config view --minify --output 'jsonpath={..context.cluster}'
}
