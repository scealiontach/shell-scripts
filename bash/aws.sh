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

@include commands
@include log

@package aws

function aws::cmd {
  $(commands::use aws) --output json "$@"
}

function aws::_jq {
  $(commands::use jq) "$@"
}

function aws::ecr {
  aws::cmd ecr "$@"
}

function aws::get_repositories {
  aws::ecr describe-repositories | aws::_jq -r '.repositories[].repositoryName' |
    sort
}

function aws::get_tags {
  local repository=${1:?}
  aws::ecr list-images "--repository-name=$repository" |
    aws::_jq -r '.imageIds[].imageTag' | sort
}

function aws::scan {
  local tag=$1
  for repository in $(aws::get_repositories); do
    if [ "$repository" = "blockchaintp/busybox" ]; then
      log::info "Skipping busybox repository"
      continue
    fi
    log::info "Scanning $repository $tag"
    aws::scan_repository "$repository" "$tag"
  done
}

function aws::scan_repository {
  local repository=${1:?}
  local set_tag=$2
  if [ -z "$set_tag" ]; then
    for tag in $(aws::get_tags "$repository"); do
      aws::refresh_scan "$repository" "$tag"
    done
  else
    if aws::get_tags "$repository" | grep -qxF "$set_tag"; then
      aws::refresh_scan "$repository" "$set_tag"
    fi
  fi
}

function aws::scan_image {
  local repository=${1:?}
  local tag=${2:?}
  local status
  status=$(aws::scan_status "$repository" "$tag")
  if [ "$status" = "IN_PROGRESS" ]; then
    log::info "Scan of $repository:$tag is already in progress"
    return 0
  elif [ "$status" = "FAILED" ]; then
    local description
    description=$(aws::_describe_findings "$repository" "$tag" |
      aws::_jq -r '.imageScanStatus.description')
    log::warn "Scan of $repository:$tag $description"
    return 1
  fi
  log::info "Scanning of $repository:$tag"
  status=$(aws::ecr start-image-scan "--repository-name=$repository" \
    --image-id imageTag="$tag" |
    aws::_jq -r '.imageScanStatus.status')
  log::info "Scan of $repository:$tag is now $status"
}

function aws::_describe_findings {
  local repository=${1:?}
  local tag=${2:?}
  aws::ecr describe-image-scan-findings "--repository-name=$repository" \
    --image-id imageTag="$tag" 2>/dev/null
}

function aws::scan_status {
  local repository=${1:?}
  local tag=${2:?}
  aws::_describe_findings "$repository" "$tag" |
    aws::_jq -r '.imageScanStatus.status'
}

function aws::is_scan_complete {
  local repository=${1:?}
  local tag=${2:?}
  local status
  status=$(aws::scan_status "$repository" "$tag")
  if [ "$status" = "COMPLETE" ]; then
    return 0
  else
    return 1
  fi
}

function aws::wait_for_scan_complete {
  local repository=${1:?}
  local tag=${2:?}
  local wait_time=${3:-10}
  local max_attempts=${4:-30}
  local attempt=0
  local status
  while [ "$attempt" -lt "$max_attempts" ]; do
    status=$(aws::scan_status "$repository" "$tag")
    if [ "$status" = "COMPLETE" ]; then
      return 0
    fi
    if [ "$status" = "FAILED" ]; then
      log::error "ECR image scan FAILED for ${repository}:${tag}"
      return 1
    fi
    log::trace "Waiting for ECR scan ${repository}:${tag} status=${status} attempt=$((attempt + 1))/${max_attempts}"
    sleep "$wait_time"
    attempt=$((attempt + 1))
  done
  log::error "Timed out waiting for ECR scan to complete for ${repository}:${tag} after ${max_attempts} attempts (${wait_time}s interval)"
  return 1
}

function aws::list_findings {
  local repository=${1:?}
  local tag=${2:?}
  # shellcheck disable=SC2016 # jq filter syntax: dollar names below are jq.
  aws::_describe_findings "$repository" "$tag" |
    aws::_jq -r '.imageScanFindings.findings[] |
      (.severity + " " + .name + " " + .uri)'
}

function aws::refresh_scan {
  local repository=${1:?}
  local tag=${2:?}
  local days_ago=${3:-7}
  local seconds_ago
  seconds_ago=$((days_ago * 86400))
  local now
  now=$(date +%s)
  local earliest
  earliest=$((now - seconds_ago))
  if aws::is_scan_complete "$repository" "$tag"; then
    local completedAt
    # ECR returns imageScanCompletedAt as a float (e.g. 1728310921.123).
    # POSIX `[ -lt ]` is integer-only, so the prior bare comparison
    # spuriously failed and the cache was defeated. `floor` (jq >= 1.5)
    # truncates to an integer for the comparison below.
    completedAt=$(aws::_describe_findings "$repository" "$tag" |
      aws::_jq -r '.imageScanFindings.imageScanCompletedAt | floor')
    if [ "$earliest" -lt "$completedAt" ]; then
      log::info "Scan of $repository:$tag was done within $days_ago days"
      return
    else
      log::info "Scan of $repository:$tag was done more than $days_ago days ago"
    fi
  fi
  aws::scan_image "$repository" "$tag"
}
