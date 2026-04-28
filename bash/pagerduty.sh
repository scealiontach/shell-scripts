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
@include log

@package pagerduty

function _curl() {
  $(commands::use curl) "$@"
}

function _jq() {
  $(commands::use jq) "$@"
}

function incident_data() {
  local service_id="${1:?}"
  local alert_type="${2:?}"
  local alert_title="${3:?}"
  local incident_key="${4}"

  # shellcheck disable=SC2016 # jq filter syntax: $-prefixed names are jq
  # variables bound by --arg above, not bash variables.
  _jq -n \
    --arg type "$alert_type" \
    --arg title "$alert_title" \
    --arg sid "$service_id" \
    --arg key "$incident_key" \
    '{
      incident: (
        {
          type: $type,
          title: $title,
          service: { id: $sid, type: "service_reference" }
        }
        + (if $key != "" then { incident_key: $key } else {} end)
      )
    }'
}

function send_incident() {
  local service_id="${1:?}"
  local alert_type="${2:?}"
  local alert_title="${3:?}"
  local alert_from="${4:?}"
  local alert_token="${5:?}"
  local incident_key="${6}"

  _curl POST --header 'Content-Type: application/json' \
    --header 'Accept: application/vnd.pagerduty+json;version=2' \
    --header "From: $alert_from" \
    --header "Authorization: Token token=$alert_token" \
    --data "$(incident_data "$service_id" "$alert_type" "$alert_title" "$incident_key")" \
    'https://api.pagerduty.com/incidents'
  log::info "Sent PagerDuty incident"
}

function send_event() {
  #set -x
  #_curl -X POST --header 'Content-Type: application/json' \
  #--header 'Accept: application/vnd.pagerduty+json;version=2' \
  #--header "From: $ALERT_FROM" \
  #--header "Authorization: Token token=$ALERT_TOKEN" \
  #--data "$(cat $PG_DATA)" 'https://api.pagerduty.com/incidents'
  log::info "Sent PagerDuty event"
}
