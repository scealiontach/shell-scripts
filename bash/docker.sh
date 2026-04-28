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

@include commands
@include doc
@include log
@include exec

@package docker

function docker::cmd() {
  @doc Smart command for docker.
  if [ -z "$SIMULATE" ]; then
    $(commands::use docker) "$@"
  else
    echo "$(commands::use docker)" "$@"
  fi
}

function docker::inspect() {
  @doc inspect the specified item
  @arg _1_ item to inspect
  local item=${1:?}
  log::info "Inspecting $item"
  docker::cmd inspect "$item"
}

function docker::pull() {
  @doc pull the specified image
  @arg _1_ the full image url to pull
  local image=${1:?}
  log::info "Pulling $image"
  docker::cmd pull -q "$image"
}

function docker::tag() {
  @doc retag one image to the provided url
  @arg _1_ the full image url of the script
  @arg _2_ the desired final url
  local from=${1:?}
  local to=${2:?}
  docker::cmd tag "$from" "$to"
}

function docker::push() {
  @doc push the specified image
  @arg _1_ the full image url to push
  local image=${1:?}
  log::info "Pushing $image"
  docker::cmd push "$image"
}

function docker::cp() {
  @doc copy an image from one image url to another. \
    Returns 0 on success, 1 if pull failed, 2 if tag failed, 3 if push failed. \
    Never calls error::exit, so callers can dispatch on $? without termination.
  @arg _1_ source
  @arg _2_ destination
  local from=${1:?}
  local to=${2:?}
  if docker::pull "$from"; then
    if docker::tag "$from" "$to"; then
      if docker::push "$to"; then
        return 0
      else
        exit_code=$?
        log::debug "Failed exit_code=$exit_code push $to"
        return 3
      fi
    else
      exit_code=$?
      log::debug "Failed exit_code=$exit_code tag from as $to"
      return 2
    fi
  else
    exit_code=$?
    log::debug "Failed exit_code=$exit_code pull $from"
    return 1
  fi
}

function docker::repo_tags_has() {
  @doc check if the image named in the from tag is also the to tag
  @arg _1_ the image to check
  @arg _2_ the tag to search for
  local from=${1:?}
  local to=${2:?}
  for tag in $(docker::inspect "$from" | jq -r '.[].RepoTags[]'); do
    local other_to
    other_to=${to//index.docker.io\//}
    if [ "$tag" = "$to" ]; then
      log::info "$from is also $to"
      return 0
    fi
    other_to=${to//index.docker.io\//}
    if [ "$tag" = "$other_to" ]; then
      log::info "$from is also $to"
      return 0
    fi
    other_to=${to//docker.io\//}
    if [ "$tag" = "$other_to" ]; then
      log::info "$from is also $to"
      return 0
    fi
  done
  return 1
}

function docker::cp_if_different() {
  @doc copy an image from one image url to another if from is different
  @arg _1_ source
  @arg _2_ destination
  local from=${1:?}
  local to=${2:?}
  if docker::pull "$from"; then
    if docker::pull "$to"; then
      #if $from and $to are the same, then return
      if docker::repo_tags_has "$from" "$to"; then
        return 0
      fi
    fi
    if docker::tag "$from" "$to"; then
      if docker::push "$to"; then
        return 0
      else
        exit_code=$?
        log::debug "Failed exit_code=$exit_code push $to"
        return 3
      fi
    else
      exit_code=$?
      log::debug "Failed exit_code=$exit_code tag from as $to"
      return 2
    fi
  else
    exit_code=$?
    log::debug "Failed exit_code=$exit_code pull $from"
    return 1
  fi
}

function docker::login() {
  local docker_user=${1:?}
  local docker_pass=${2:?}
  local registry=${3}

  echo "$docker_pass" | docker::cmd login -u "$docker_user" --password-stdin \
    "$registry"
}

function docker::registrycmd {
  local url=${1:?}
  local registry=${2:?}
  local basic_token
  basic_token=$(jq -r ".auths.\"$registry\".auth" ~/.docker/config.json)
  $(commands::use curl) -s -H "Authorization: Basic $basic_token" "https://$registry/v2/$url"
}

function docker::list_repositories {
  local registry=${1:?}
  docker::registrycmd _catalog "$registry" | jq -r '.repositories[]' |
    sort
}

function docker::list_tags {
  local repository=${1:?}
  local registry=${2?}
  docker::registrycmd "$repository/tags/list" "$registry" | jq -r '.tags[]' |
    sort -V
}

function docker::list_versions {
  local repository=${1:?}
  local registry=${2?}
  docker::list_tags "$repository" "$registry" |
    grep -E 'BTP[0-9]+.[0-9]+.[0-9]+(rc[0-9]+)?(-[0-9]+-[a-z0-9]{8,10})?(-[0-9]+.[0-9]+.[0-9]+(p[0-9]+(-[0-9]+-[a-z0-9]{8,10})?)?)?' |
    sort -V
}

function docker::list_official_versions {
  local repository=${1:?}
  local registry=${2?}
  docker::list_tags "$repository" "$registry" | grep -E \
    '^BTP[0-9]+.[0-9]+.[0-9]+(rc[0-9]+)?(-[0-9]+.[0-9]+.[0-9]+(p[0-9]+)?)?$' |
    sort -V
}

function docker::promote_latest() {
  local organization=${1:?}
  local registry=${2:?}
  local target_tag=${3:?}
  shift 3

  for repo in $(docker::list_repositories "$registry" |
    grep "^${organization}/"); do
    local src_version
    src_version=$(docker::list_official_versions "$repo" "$registry" | grep "^${target_tag}-" | sort -V |
      tail -1)
    if [ -z "$src_version" ]; then
      log::warn "$repo has no official version in $target_tag"
      continue
    fi
    docker::cp_if_different "$registry/$repo:$src_version" "$registry/$repo:$target_tag"
    for extra_registry in "$@"; do
      docker::cp_if_different "$registry/$repo:$src_version" "$extra_registry/$repo:$src_version"
      docker::cp_if_different "$registry/$repo:$target_tag" "$extra_registry/$repo:$target_tag"
    done
  done
}
