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

@include doc

@package log

#-----------------------------------------------------------------------------
# Configurables

COMPONENT_NAME="${COMPONENT_NAME:-$(basename "${BASH_SOURCE[-1]}")}"
LOGDIR="${LOGDIR:-$HOME}"
LOGFILE="${LOGFILE:-$HOME/${COMPONENT_NAME}.log}"
#shellcheck disable=SC2034
LOGFILE_DISABLE=true

export LOGFILE
export LOG_FORMAT='%DATE %PID [%LEVEL] %MESSAGE'
export LOG_DATE_FORMAT='+%F %T %Z'    # Eg: 2014-09-07 21:51:57 EST
export LOG_COLOR_DEBUG="\033[0;37m"   # Gray
export LOG_COLOR_INFO="\033[0m"       # White
export LOG_COLOR_NOTICE="\033[1;32m"  # Green
export LOG_COLOR_WARNING="\033[1;33m" # Yellow
export LOG_COLOR_ERROR="\033[1;31m"   # Red
export LOG_COLOR_CRITICAL="\033[44m"  # Blue Background
export LOG_COLOR_ALERT="\033[43m"     # Yellow Background
export LOG_COLOR_EMERGENCY="\033[41m" # Red Background
export RESET_COLOR="\033[0m"

#-----------------------------------------------------------------------------
# LOG_LEVEL -> enabled-levels mapping (cumulative)
#
#   LOG_LEVEL=0  ERROR/CRITICAL/ALERT/EMERGENCY/NOTICE only (default)
#   LOG_LEVEL=1  + WARNING
#   LOG_LEVEL=2  + INFO
#   LOG_LEVEL=3  + DEBUG
#   LOG_LEVEL=4  + TRACE
#
# log::level "$N" sets LOG_LEVEL=N and recomputes the LOG_DISABLE_*
# flags. Below the file calls log::level "$LOG_LEVEL" once at source
# time so the disable flags are deterministic — without that call, the
# flags are unset and tests like `[ "$LOG_DISABLE_INFO" = "false" ]`
# evaluate false (empty != "false"), silently disabling output.
# options::standard's -v flag drives this via log::level_increase.
#-----------------------------------------------------------------------------
# Individual Log Functions
# These can be overwritten to provide custom behavior for different log levels
LOG_LEVEL=${LOG_LEVEL:-0}
function log::level() {
  if [ -z "$1" ]; then
    echo "${LOG_LEVEL}"
    return
  fi
  local level=${1:?}
  LOG_DISABLE_TRACE=true
  LOG_DISABLE_DEBUG=true
  LOG_DISABLE_INFO=true
  LOG_DISABLE_WARNING=true
  if ((level > 0)); then
    LOG_DISABLE_WARNING=false
  fi
  if ((level > 1)); then
    LOG_DISABLE_INFO=false
  fi
  if ((level > 2)); then
    LOG_DISABLE_DEBUG=false
  fi
  if ((level > 3)); then
    LOG_DISABLE_TRACE=false
  fi
  LOG_LEVEL=$level
}

# Initialise the LOG_DISABLE_* flags from LOG_LEVEL at source time so
# scripts that don't pass -v still get deterministic gating. Skip if a
# caller has already pre-set any of the disable flags directly (so
# explicit pre-set values survive sourcing).
if [ -z "${LOG_DISABLE_INFO+set}" ] && [ -z "${LOG_DISABLE_DEBUG+set}" ] &&
  [ -z "${LOG_DISABLE_WARNING+set}" ] && [ -z "${LOG_DISABLE_TRACE+set}" ]; then
  log::level "$LOG_LEVEL"
fi

function log::level_increase() {
  @doc Increase the LOG_LEVEL
  ((LOG_LEVEL += 1))
  log::level "$LOG_LEVEL"
}

function log::level_decrease() {
  @doc Decrease the LOG_LEVEL
  ((LOG_LEVEL -= 1))
  log::level "$LOG_LEVEL"
}

TRACE() {
  deprecated log::trace "$@"
}
log::trace() {
  @doc Issue a TRACE level message
  if [ "$LOG_DISABLE_TRACE" = "false" ]; then
    LOG_HANDLER_DEFAULT TRACE "$@"
  fi
}

DEBUG() {
  deprecated log::debug "$@"
}
log::debug() {
  @doc Issue a DEBUG level message
  if [ "$LOG_DISABLE_DEBUG" = "false" ]; then
    LOG_HANDLER_DEFAULT DEBUG "$@"
  fi
}

INFO() {
  deprecated log::info "$@"
}
log::info() {
  @doc Issue an INFO level message
  if [ "$LOG_DISABLE_INFO" = "false" ]; then
    LOG_HANDLER_DEFAULT INFO "$@"
  fi
}

WARNING() {
  deprecated log::warn "$@"
}
log::warn() {
  @doc Issue a WARNING level message
  if [ "$LOG_DISABLE_WARNING" = "false" ]; then
    LOG_HANDLER_DEFAULT WARNING "$@"
  fi
}

# ERRORS indicate an event which make it impossible to continue
#   they should never be filtered
ERROR() {
  deprecated log::error "$@"
}
log::error() {
  @doc Issue an unhideable ERROR level message
  LOG_HANDLER_DEFAULT ERROR "$@"
}

# CRITICALS indicate an event which make it impossible to continue,
#   and likely some sort of data loss/corruption
#   they should never be filtered
CRITICAL() {
  deprecated log::critical "$@"
}
log::critical() {
  @doc Issue a CRITICAL notice.
  LOG_HANDLER_DEFAULT CRITICAL "$@"
}

# The following are log levels which are meant to be picked up by external
# systems, or other outside actors.
# They are not to be filtered. In oder of descending importance

#EMERGENCY - issues that should be dealt with immediately
EMERGENCY() {
  deprecated log::emergency "$@"
}
log::emergency() {
  @doc Issue a EMERGENCY notice.
  LOG_HANDLER_DEFAULT EMERGENCY "$@"
}

# ALERT - issues that should be dealt with soon
ALERT() {
  deprecated log::alert "$@"
}
log::alert() {
  @doc Issue an ALERT notice.
  LOG_HANDLER_DEFAULT ALERT "$@"
}

# NOTICE - issues that should be dealt with optionally
NOTICE() {
  deprecated log::notice "$@"
}
log::notice() {
  @doc Issue a NOTICE notice.
  LOG_HANDLER_DEFAULT NOTICE "$@"
}

#--------------------------------------------------------------------------------------------------
# Helper Functions

function log::_format() {
  @doc Format a log line using LOG_FORMAT and LOG_DATE_FORMAT.
  @arg _1_ log level e.g. INFO
  @arg _2_ log message
  local level="$1"
  local log="$2"
  local pid=$$
  local date
  date="$(date "$LOG_DATE_FORMAT")"
  local formatted_log="$LOG_FORMAT"
  formatted_log="${formatted_log/'%MESSAGE'/$log}"
  formatted_log="${formatted_log/'%LEVEL'/$level}"
  formatted_log="${formatted_log/'%PID'/$pid}"
  formatted_log="${formatted_log/'%DATE'/$date}"
  printf '%s\n' "$formatted_log"
}
# Deprecated public name retained as a parens-only shim so the bare identifier
# does not violate the lib-funcs-must-be-namespaced lint and external callers
# continue to resolve.
FORMAT_LOG() {
  log::_format "$@"
}

function log::log() {
  @doc Dispatch a log line to the matching log level function.
  @arg _1_ log level - TRACE, DEBUG, INFO, WARN/WARNING, NOTICE, ERROR, \
    CRITICAL, ALERT, or EMERGENCY
  @arg _2_ log message
  local level="${1^^}"
  local log="$2"
  case "$level" in
    TRACE) log::trace "$log" ;;
    DEBUG) log::debug "$log" ;;
    INFO) log::info "$log" ;;
    WARN | WARNING) log::warn "$log" ;;
    NOTICE) log::notice "$log" ;;
    ERROR) log::error "$log" ;;
    CRITICAL) log::critical "$log" ;;
    ALERT) log::alert "$log" ;;
    EMERGENCY) log::emergency "$log" ;;
    *) log::error "Unknown log level: $1" ;;
  esac
}
LOG() {
  log::log "$@"
}

log() {
  deprecated log::log "$@"
}
#--------------------------------------------------------------------------------------------------
# Log Handlers
#
# LOG_HANDLER_DEFAULT, LOG_HANDLER_COLORTERM, and LOG_HANDLER_LOGFILE are the
# documented override hooks: callers redefine them to change handler behaviour
# at runtime. They keep their bare names (parens-only style) so the override
# pattern continues to work and the `lib-funcs-must-be-namespaced` lint hook
# does not flag them. The `log::_handler_*` aliases below give new code a
# namespaced surface that delegates to whatever the override hook currently
# points to.

# All log levels call this handler (by default...), so this is a great place to put any standard
# logging behavior
# Usage: LOG_HANDLER_DEFAULT <log level> <log message>
# Eg: LOG_HANDLER_DEFAULT DEBUG "My debug log"
LOG_HANDLER_DEFAULT() {
  # $1 - level
  # $2 - message
  local formatted_log
  formatted_log="$(log::_format "$@")"
  LOG_HANDLER_COLORTERM "$1" "$formatted_log"
  if [ -z "$LOGFILE_DISABLE" ] || [ "$LOGFILE_DISABLE" != "true" ]; then
    LOG_HANDLER_LOGFILE "$1" "$formatted_log"
  fi
}
function log::_handler_default() {
  @doc Namespaced alias for the LOG_HANDLER_DEFAULT override hook.
  LOG_HANDLER_DEFAULT "$@"
}

# Outputs a log to the stdout, colourised using the LOG_COLOR configurables
# Usage: LOG_HANDLER_COLORTERM <log level> <log message>
# Eg: LOG_HANDLER_COLORTERM CRITICAL "My critical log"
LOG_HANDLER_COLORTERM() {
  local level="$1"
  local log="$2"
  local color_variable="LOG_COLOR_$level"
  local color="${!color_variable}"
  log="$color$log$RESET_COLOR"
  echo >&2 -e "$log"
}
function log::_handler_colorterm() {
  @doc Namespaced alias for the LOG_HANDLER_COLORTERM override hook.
  LOG_HANDLER_COLORTERM "$@"
}

# Appends a log to the configured logfile
# Usage: LOG_HANDLER_LOGFILE <log level> <log message>
# Eg: LOG_HANDLER_LOGFILE NOTICE "My critical log"
LOG_HANDLER_LOGFILE() {
  local level="$1"
  local log="$2"
  local log_path
  log_path="$(dirname "$LOGFILE")"
  [ -d "$log_path" ] || mkdir -p "$log_path"
  echo "$log" >>"$LOGFILE"
}
function log::_handler_logfile() {
  @doc Namespaced alias for the LOG_HANDLER_LOGFILE override hook.
  LOG_HANDLER_LOGFILE "$@"
}
