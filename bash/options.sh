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
@include doc
@include log

@package options

declare -g -a OPTIONS
declare -g -A OPTIONS_DOC
declare -g -A OPTIONS_OPTIONAL
declare -g -A OPTIONS_HAS_ARGS
declare -g -A OPTIONS_PARSE_FUNCS
declare -g -A OPTIONS_ENVIRONMENT
declare -g OPTIONS_DESCRIPTION

function options::syntax_exit() {
  @doc Print the command syntax and exit
  # Use BASH_SOURCE[-1] (bottom of the call stack = entry script) instead
  # of BASH_SOURCE[2]: when -h is dispatched via OPTIONS_PARSE_FUNCS the
  # call stack is one frame deeper than on the no-args path, and [2]
  # then resolves to options.sh itself. SUR-1926.
  options::help "$(basename "${BASH_SOURCE[-1]}")"
  exit 1
}

function options::clear() {
  @doc Clear the current options configuration
  OPTIONS=()
  OPTIONS_DOC=()
  OPTIONS_OPTIONAL=()
  OPTIONS_HAS_ARGS=()
  OPTIONS_PARSE_FUNCS=()
  OPTIONS_ENVIRONMENT=()
  OPTIONS_DESCRIPTION=""
  options::add -o h -d "prints syntax and exits" -f options::syntax_exit &&
    HELP_OPT_ADDED="true"
}

function options::set_description() {
  @doc Set the description for the command using this options set.
  OPTIONS_DESCRIPTION=${1:?}
}
# shellcheck disable=SC2120
function options::description() {
  @doc Print the description of the command using this option set.
  @arg _1_ the description to set, when empty just print the description
  if [ -z "$1" ]; then
    if [ -n "$OPTIONS_DESCRIPTION" ]; then
      printf "DESCRIPTION\n"
      printf "\n"
      printf "  %s\n" "$OPTIONS_DESCRIPTION" |
        sed -e 's/\ \ /\ /g' | $(commands::use fold) -s
      printf "\n"
    fi
  else
    options::set_description "$1"
  fi
}

function options::add() {
  @doc add an option to the current configuration
  local option=""
  local argument="false"
  local optional="true"
  local description="no description"
  local parse_fn=""
  local environment_var=""
  local opt
  while [ "$#" -gt 0 ]; do
    opt="$1"
    shift
    case "$opt" in
      -o)
        @arg -o "<arg>" the option to add
        option="${1}"
        shift
        ;;
      -d)
        @arg -d "<arg>" the description of the option
        description="${1}"
        shift
        ;;
      -m)
        @arg -m the option is mandatory
        optional="false"
        ;;
      -a)
        @arg -a the option has an argument
        argument="true"
        ;;
      -e)
        @arg -a "<arg>" the option will set the named global environment var \
          with its argument
        environment_var="${1}"
        declare -g "${environment_var}="
        shift
        ;;
      -x)
        @arg -x "<arg>" the option will set the named global environment var \
          as a flag
        environment_var="${1}"
        declare -g "${environment_var}=false"
        shift
        ;;
      -f)
        @arg -f "<arg>" the option will call the named function with its argument
        parse_fn="${1}"
        shift
        ;;
      *)
        return 1
        ;;
    esac
  done
  if [ -z "$option" ]; then
    echo "Invalid option specification"
    return 1
  fi

  OPTIONS+=("$option")
  OPTIONS_DOC[$option]="$description"
  OPTIONS_OPTIONAL[$option]="$optional"
  OPTIONS_HAS_ARGS[$option]="$argument"
  [ -n "$parse_fn" ] && OPTIONS_PARSE_FUNCS[$option]="$parse_fn"
  [ -n "$environment_var" ] && OPTIONS_ENVIRONMENT[$option]="$environment_var"
}

function options::spec() {
  @doc echo the getopt spec defined by the options
  local spec=""
  for opt in "${OPTIONS[@]}"; do
    spec="${spec}${opt}"
    if [ "${OPTIONS_HAS_ARGS[$opt]}" = "true" ]; then
      spec="${spec}:"
    fi
  done
  echo "$spec"
}

[ -z "$HELP_OPT_ADDED" ] &&
  options::add -o h -d "prints syntax and exits" -f options::syntax_exit &&
  HELP_OPT_ADDED="true"

function options::syntax() {
  @doc echo the syntax of these options for as if used by command specified
  # shellcheck disable=SC2086
  @arg _1_ the command specified
  local command=$1
  local spec=""
  local items=()
  local opt
  local item
  for opt in "${OPTIONS[@]}"; do
    item="-${opt}"
    if [ "${OPTIONS_HAS_ARGS[$opt]}" = "true" ]; then
      item="$item <arg>"
    fi
    if [ "${OPTIONS_OPTIONAL[$opt]}" = "true" ]; then
      item="[$item]"
    fi
    items+=("$item")
  done
  printf "%s\n" "SYNTAX"
  printf "\n  %s %s\n\n" "$command" "${items[*]}"
}

function options::doc() {
  @doc print the documentation for the options
  local count=0
  local opt
  local mandatory
  local args
  printf "%s\n" "OPTIONS"
  for opt in "${OPTIONS[@]}"; do
    local description="${OPTIONS_DOC[$opt]}"
    if [ "${OPTIONS_OPTIONAL[$opt]}" = "true" ]; then
      mandatory=""
    else
      mandatory=" (required)"
    fi
    if [ "${OPTIONS_HAS_ARGS[$opt]}" = "false" ]; then
      args=""
    else
      args="<arg>"
    fi
    printf "\t-%s %-5s  %-40s\n" "$opt" "$args" "$mandatory $description"
    ((count += 1))
  done
  printf "\n"
}

function options::help() {
  @doc print the full help for these options either for the calling script \
    or for the specified command
  # shellcheck disable=SC2086
  @arg _1_ optionally specify the command name
  local cmd
  if [ -z "$1" ]; then
    # SUR-1926: BASH_SOURCE[-1] = entry script regardless of how deep the
    # dispatch path is (no-args -> options::syntax_exit -> options::help vs
    # -h -> OPTIONS_PARSE_FUNCS -> options::syntax_exit -> options::help).
    cmd="${BASH_SOURCE[-1]}"
  else
    cmd="$1"
  fi
  options::syntax "$(basename "${cmd}")"
  options::description
  options::doc "$(basename "${cmd}")"
}

function options::getopts() {
  @doc run getops for the options specification
  getopts "$(options::spec)" "$@"
}

function options::standard() {
  @doc Add the standard option set. The -v flag drives log::level_increase \
    which raises LOG_LEVEL by 1 each time it is given. See bash/log.sh \
    for the LOG_LEVEL to enabled-levels mapping from 0 to 4. The default \
    level 0 emits only ERROR, CRITICAL, ALERT, EMERGENCY, and NOTICE.
  options::add -o v -d "set verbosity level" -f log::level_increase
}

function options::parse_available() {
  @doc parse the options using the provided argument array
  @arg "$@" the provided argument array
  while options::getopts opt "$@"; do
    if [ "$opt" != "?" ]; then
      if [ -n "${OPTIONS_ENVIRONMENT[$opt]}" ]; then
        local varName="${OPTIONS_ENVIRONMENT[$opt]}"
        local val
        if [ -n "${OPTARG}" ]; then
          val="${OPTARG}"
        else
          val="true"
        fi
        declare -g "$varName=${val}"
      elif [ -n "${OPTIONS_PARSE_FUNCS[$opt]}" ]; then
        if command -v "${OPTIONS_PARSE_FUNCS[$opt]}" >/dev/null; then
          ${OPTIONS_PARSE_FUNCS[$opt]} "${OPTARG}"
        else
          echo "ERROR: for option ($opt) parse_functions must be defined or left out"
          exit 1
        fi
      fi
    else
      return 1
    fi
  done
}

function options::parse() {
  @doc parse the options using the provided argument array, if no args passes print syntax and exit
  @arg "$@" the provided argument array
  options::parse_available "$@"
  if [ -z "${NO_SYNTAX_EXIT}" ] && [ "${OPTIND}" -eq 1 ]; then
    options::syntax_exit
  fi
}
