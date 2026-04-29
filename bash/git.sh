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

@package git

function git::cmd() {
  @doc Smart command for git.
  @arg @ args to git
  $(commands::use git) "$@"
}

function git::tagsinhistory() {
  @doc List all the tags in the history of this commit.
  git::cmd log --no-walk --pretty="%d" -n 100000 | grep "(tag" |
    awk '{print $2}' | sed -e 's/)//' |
    awk '{ for (i=NF; i>1; i--) printf("%s ",$i); print $1; }' |
    sed -e 's/,$//'
}

function git::commit_url_base() {
  @doc Return the commit-URL prefix: https://github.com/owner/repo/commit
  @doc Emits empty string for non-GitHub remotes.
  local origin_url
  origin_url=$(git remote -v | grep "^origin" | head -1)
  if echo "$origin_url" | grep -q github; then
    local slug
    slug=$(echo "$origin_url" | awk '{print $2}')
    slug=${slug//.git/}
    slug=${slug//git@github.com:/}
    slug=${slug//https:\/\/github.com\//}
    slug=${slug//http:\/\/github.com\//}
    echo "https://github.com/$slug/commit"
  fi
}

function git::projecturl() {
  deprecated git::commit_url_base "$@"
}

function git::project_url() {
  @doc Return the bare project URL: https://github.com/owner/repo
  @doc No trailing /commit suffix. Emits empty string for non-GitHub remotes.
  local origin_url
  origin_url=$(git remote -v | grep "^origin" | head -1)
  if echo "$origin_url" | grep -q github; then
    local slug
    slug=$(echo "$origin_url" | awk '{print $2}')
    slug=${slug//.git/}
    slug=${slug//git@github.com:/}
    slug=${slug//https:\/\/github.com\//}
    slug=${slug//http:\/\/github.com\//}
    echo "https://github.com/$slug"
  fi
}

function git::commits() {
  @doc List the git commits between two commits.
  @arg _1_ from
  @arg _2_ to
  local from=$1
  local to=$2
  [ -z "$to" ] && to="HEAD"
  git::cmd log "$from"..."$to" --pretty=format:'%h'
}

function git::log_fromto() {
  @doc Get the log messages from one commit ending at another.
  @arg _1_ from
  @arg _2_ to
  local from=$1
  local to=$2
  [ -z "$to" ] && to="HEAD"
  git::cmd log "$from"..."$to" --no-merges --pretty=format:"* %h %s"
}

function git::files_changed() {
  @doc List the files changed in a commit.
  @arg _1_ the commit to examine
  local commit=$1
  git::cmd diff-tree --no-commit-id --name-only -r "$commit" | sort
}

function git::describe() {
  @doc Smart command for git::cmd describe.
  git::cmd describe "$@"
}

function git::version_with_dirty_marker() {
  @doc Get the describe-derived version string with a literal "-dirty" suffix appended unconditionally.
  echo "$(git::describe --tags 2>/dev/null)-dirty"
}

function git::dirty_version() {
  deprecated git::version_with_dirty_marker "$@"
}
