#!/usr/bin/env bats
# SUR-1858: aws.sh must declare @include log directly so it sources
# log::* in isolation, not just through transitive options/commands
# pulls.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
}

@test "aws.sh sourced in isolation resolves log::info" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    declare -F log::info >/dev/null
  "
  [ "$status" -eq 0 ]
}

@test "aws.sh sourced in isolation resolves log::warn" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    declare -F log::warn >/dev/null
  "
  [ "$status" -eq 0 ]
}

@test "aws::is_scan_complete returns 0 when scan status is COMPLETE" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    aws::scan_status() { echo 'COMPLETE'; }
    aws::is_scan_complete myrepo mytag
  "
  [ "$status" -eq 0 ]
}

@test "aws::is_scan_complete returns 1 when scan status is IN_PROGRESS" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    aws::scan_status() { echo 'IN_PROGRESS'; }
    aws::is_scan_complete myrepo mytag
  "
  [ "$status" -ne 0 ]
}

@test "aws::is_scan_complete returns 1 for any non-COMPLETE status" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    aws::scan_status() { echo 'FAILED'; }
    aws::is_scan_complete myrepo mytag
  "
  [ "$status" -ne 0 ]
}

@test "aws::wait_for_scan_complete returns non-zero after bounded attempts when stuck (SUR-2340)" {
  run bash -c "
    export LOG_DISABLE_TRACE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    aws::scan_status() { echo 'IN_PROGRESS'; }
    sleep() { :; }
    aws::wait_for_scan_complete myrepo mytag 0 5
  "
  [ "$status" -ne 0 ]
}

@test "aws::wait_for_scan_complete returns non-zero promptly on FAILED status (SUR-2340)" {
  run bash -c "
    export LOG_DISABLE_TRACE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    aws::scan_status() { echo 'FAILED'; }
    sleep() { :; }
    aws::wait_for_scan_complete myrepo mytag 0 99
  "
  [ "$status" -ne 0 ]
}

# SUR-2459: aws::scan_repository grep uses literal fixed-string match

@test "aws::scan_repository does not match '1.2.3' against literal tag '1X2X3' (SUR-2459)" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    aws::get_tags() { echo '1X2X3'; }
    aws::refresh_scan() { echo 'CALLED'; }
    aws::scan_repository myrepo '1.2.3'
  "
  [ "$status" -eq 0 ]
  # refresh_scan must NOT have been called — tag '1.2.3' is not '1X2X3' literally
  [[ "$output" != *"CALLED"* ]]
}

# SUR-2477: aws::refresh_scan cache window and jq floor on fractional timestamps

@test "aws::refresh_scan skips aws::scan_image when scan is COMPLETE and within cache window (SUR-2477)" {
  run bash -c "
    export LOG_DISABLE_INFO=true
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    date() { printf '%s\n' '2000000000'; }
    aws::_describe_findings() {
      printf '%s\n' '{\"imageScanStatus\":{\"status\":\"COMPLETE\"},\"imageScanFindings\":{\"imageScanCompletedAt\":1999990000.987}}'
    }
    aws::scan_image() { echo SCAN_IMAGE_CALLED; return 0; }
    aws::refresh_scan myrepo mytag 7
  "
  [ "$status" -eq 0 ]
  [[ "$output" != *"SCAN_IMAGE_CALLED"* ]]
}

@test "aws::refresh_scan calls aws::scan_image when COMPLETE scan is older than cache window (SUR-2477)" {
  run bash -c "
    export LOG_DISABLE_INFO=true
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    date() { printf '%s\n' '2000000000'; }
    aws::_describe_findings() {
      printf '%s\n' '{\"imageScanStatus\":{\"status\":\"COMPLETE\"},\"imageScanFindings\":{\"imageScanCompletedAt\":1000.1}}'
    }
    aws::scan_image() { echo SCAN_IMAGE_CALLED; return 0; }
    aws::refresh_scan myrepo mytag 7
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"SCAN_IMAGE_CALLED"* ]]
}

@test "aws::refresh_scan calls aws::scan_image when scan is not COMPLETE (SUR-2477)" {
  run bash -c "
    export LOG_DISABLE_INFO=true
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    date() { printf '%s\n' '2000000000'; }
    aws::_describe_findings() {
      printf '%s\n' '{\"imageScanStatus\":{\"status\":\"IN_PROGRESS\"}}'
    }
    aws::scan_image() { echo SCAN_IMAGE_CALLED; return 0; }
    aws::refresh_scan myrepo mytag 7
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"SCAN_IMAGE_CALLED"* ]]
}

@test "aws::refresh_scan uses jq floor so fractional scan time does not spuriously refresh (SUR-2477)" {
  run bash -c "
    export LOG_DISABLE_INFO=true
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    # Window edge: earliest = 2000000000 - 604800 = 1999395200
    # Integer part 1999395200 is not fresh; 1999395200.001 floor is still 1999395200,
    # so earliest < completedAt is false — would refresh without careful equality.
    # Use completedAt just above earliest as integer: 1999395201.999 floors to 1999395201.
    date() { printf '%s\n' '2000000000'; }
    aws::_describe_findings() {
      printf '%s\n' '{\"imageScanStatus\":{\"status\":\"COMPLETE\"},\"imageScanFindings\":{\"imageScanCompletedAt\":1999395201.999}}'
    }
    aws::scan_image() { echo SCAN_IMAGE_CALLED; return 0; }
    aws::refresh_scan myrepo mytag 7
  "
  [ "$status" -eq 0 ]
  [[ "$output" != *"SCAN_IMAGE_CALLED"* ]]
}
