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
@include doc
@include error
@include exec

@package secret

declare -g -A SECRETS
declare -g -A SECRETS_FILES
declare -g -a SECRET_TMPFILES
declare -g SECRET_TRAP_INSTALLED=${SECRET_TRAP_INSTALLED:-false}
declare -g SECRET_PREV_EXIT_TRAP=""
declare -g SECRET_PREV_INT_TRAP=""
declare -g SECRET_PREV_TERM_TRAP=""

function secret::_run_chained_trap {
  @doc Internal - run secret::clear and afterwards run the caller \
    pre-existing trap captured at install time for the given signal.
  @arg _1_ signal name EXIT INT or TERM
  local sig=${1:?}
  secret::clear
  local prev=
  case "$sig" in
    EXIT) prev=$SECRET_PREV_EXIT_TRAP ;;
    INT) prev=$SECRET_PREV_INT_TRAP ;;
    TERM) prev=$SECRET_PREV_TERM_TRAP ;;
    *) return ;;
  esac
  if [ -n "$prev" ]; then
    # trap -p SIG returns the literal text:
    #   trap -- <single-quoted-CMD> SIG
    # Strip the wrapper, then unquote the CMD via eval-set-positional-args
    # so embedded single quotes (escaped by bash as the standard
    # close/escape/reopen sequence) round-trip cleanly.
    local cmd_quoted=${prev#trap -- }
    cmd_quoted=${cmd_quoted% "$sig"}
    eval "set -- $cmd_quoted"
    eval "$1"
  fi
}

function secret::_install_cleanup_trap {
  @doc Internal - install the EXIT/INT/TERM trap that calls secret::clear \
    exactly once per shell. Must be invoked from the parent shell scope so \
    the trap is in the right place. The registration helpers call this. \
    SUR-2324: captures any pre-existing caller trap on EXIT/INT/TERM so the \
    chained handler runs the caller pre-existing trap after secret::clear \
    instead of silently overwriting it.
  if [ "$SECRET_TRAP_INSTALLED" != "true" ]; then
    SECRET_PREV_EXIT_TRAP=$(trap -p EXIT)
    SECRET_PREV_INT_TRAP=$(trap -p INT)
    SECRET_PREV_TERM_TRAP=$(trap -p TERM)
    trap 'secret::_run_chained_trap EXIT' EXIT
    trap 'secret::_run_chained_trap INT' INT
    trap 'secret::_run_chained_trap TERM' TERM
    SECRET_TRAP_INSTALLED=true
  fi
}

function secret::register_env {
  @doc Register a secret under the provided name
  @arg _1_ the secret name
  @arg _2_ optional - the name of a different env var containing the secret val
  { set +x; } 2>/dev/null
  local varName=${1:?}
  local targetVar=$2
  if [ -z "$targetVar" ]; then
    SECRETS[$varName]="environment"
    declare -g "$varName=${!varName}"
  else
    SECRETS[$varName]="environment"
    declare -g -n "$varName=${targetVar}"
  fi
  secret::_install_cleanup_trap
}

function secret::register_file {
  @doc Register a secret in the specified file under the provided name
  @arg _1_ the secret name
  @arg _2_ the file containing the secret
  { set +x; } 2>/dev/null
  local varName=${1:?}
  local file=${2:?}
  SECRETS[$varName]="file"
  SECRETS_FILES[$varName]="$file"
  declare -g "$varName=$(cat "${SECRETS_FILES[$varName]}")"
  secret::_install_cleanup_trap
}

function secret::exists {
  @doc Check if secret exists.
  @arg _1_ name of the secret
  local secretName=${1:?}
  if [ -n "${SECRETS[$secretName]}" ]; then
    case "${SECRETS[$secretName]}" in
      environment)
        if [ -n "${!secretName}" ]; then
          return 0
        else
          return 1
        fi
        ;;
      file)
        if [ -r "${SECRETS_FILES[$secretName]}" ]; then
          return 0
        else
          return 1
        fi
        ;;
      *)
        return 1
        ;;
    esac
  else
    return 1
  fi
}

function secret::must_exist {
  @doc Verify a secret exists or exit with error
  @arg _1_ name of the secret
  local secretName=${1:?}
  if ! secret::exists "$secretName"; then
    error::exit "No such secret $secretName"
  fi
}

function secret::as_file {
  @doc Render the named secret as a temporary file and return the name
  @arg _1_ name of the secret
  { set +x; } 2>/dev/null
  local secretName=${1:?}
  secret::must_exist "$secretName"
  case "${SECRETS[$secretName]}" in
    environment)
      secret::_env_as_file "$secretName"
      ;;
    file)
      secret::_file_as_file "$secretName"
      ;;
    *)
      return 1
      ;;
  esac
}

function secret::_file_as_file {
  @doc Internal - return the path of a file-backed secret.
  @arg _1_ name of the secret
  { set +x; } 2>/dev/null
  local secretName=${1:?}
  printf "%s" "${SECRETS_FILES[$secretName]}"
}

function secret::_env_as_file {
  @doc Internal - materialize an env-backed secret to a 0600 tempfile and \
    echo the path. Errors out if the named env var is unset or empty.
  @arg _1_ name of the env var holding the secret
  { set +x; } 2>/dev/null
  local secretName=${1:?}
  if [ -z "${!secretName-}" ]; then
    error::exit "secret::_env_as_file: env var '$secretName' is unset or empty"
  fi
  local tmpFile
  tmpFile=$(mktemp)
  chmod 600 "$tmpFile"
  SECRET_TMPFILES+=("$tmpFile")
  # Indirect expansion (works for exported and non-exported globals) avoids
  # the printenv-only-sees-exported-vars failure mode that wrote a 0-byte
  # file when secret::register_env had registered without exporting.
  # printf '%s\n' preserves the trailing newline that printenv emitted, so
  # downstream line-oriented consumers (PEM readers, etc.) see the same
  # on-disk byte content as before.
  printf '%s\n' "${!secretName}" >"$tmpFile"
  echo "$tmpFile"
}

function secret::clear {
  @doc Clear secret temporary files.
  if [ -n "${SECRET_TMPFILES[0]}" ]; then
    rm -f "${SECRET_TMPFILES[@]}"
  fi
}
