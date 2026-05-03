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

@include annotations
@include commands
@include error
@include log

@package pagerduty

function pagerduty::_curl() {
  $(commands::use curl) "$@"
}

function pagerduty::_jq() {
  $(commands::use jq) "$@"
}

function pagerduty::_incident_data() {
  local service_id="${1:?}"
  local alert_type="${2:?}"
  local alert_title="${3:?}"
  local incident_key="${4}"

  # shellcheck disable=SC2016 # jq filter syntax: $-prefixed names are jq
  # variables bound by --arg above, not bash variables.
  pagerduty::_jq -n \
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

function pagerduty::send_incident() {
  @doc Submit an incident via the PagerDuty REST Incidents API
  local service_id="${1:?}"
  local alert_type="${2:?}"
  local alert_title="${3:?}"
  local alert_from="${4:?}"
  local alert_token="${5:?}"
  local incident_key="${6}"

  local rc=0
  # --fail-with-body needs curl >= 7.76.0 (Apr 2021). On older hosts curl
  # exits non-zero with "option unknown" — caller still sees a non-zero rc
  # below, just with a less specific error body than --fail-with-body
  # would give. Drop to plain --fail if a target environment ships an
  # older curl.
  pagerduty::_curl --fail-with-body -sS \
    -X POST --header 'Content-Type: application/json' \
    --header 'Accept: application/vnd.pagerduty+json;version=2' \
    --header "From: $alert_from" \
    --header "Authorization: Token token=$alert_token" \
    --data "$(pagerduty::_incident_data "$service_id" "$alert_type" "$alert_title" "$incident_key")" \
    "${PAGERDUTY_INCIDENTS_URL:-https://api.pagerduty.com/incidents}" || rc=$?
  if [ "$rc" -ne 0 ]; then
    log::error "PagerDuty incident send failed (curl rc=$rc)"
    return "$rc"
  fi
  log::info "Sent PagerDuty incident"
}

send_incident() {
  deprecated pagerduty::send_incident "$@"
}

function pagerduty::send_event() {
  @doc Submit an event via the PagerDuty Events API v2. Not implemented.
  # The Events API v2 uses a different endpoint
  # (events.pagerduty.com/v2/enqueue), a different auth model
  # (routing_key, not API token), and a different payload schema. Until
  # someone wires that up, fail loudly so callers don't silently drop
  # alerts the way the previous body did (it just logged "Sent" and
  # returned 0 with no HTTP request at all).
  error::exit "pagerduty::send_event not implemented (use pagerduty::send_incident)"
}

send_event() {
  deprecated pagerduty::send_event "$@"
}
