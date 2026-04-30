#!/usr/bin/env bats
# SUR-1934 / SUR-1935: bash/trust-server must
#   * fail loudly when /etc/os-release is unreadable,
#   * dispatch to add-certs-amzn for the RPM family (amzn, fedora,
#     centos, rhel, rocky, almalinux),
#   * dispatch to add-certs-ubuntu for the Debian family
#     (ubuntu, pop, debian),
#   * exit non-zero with a clear "unsupported distro" error for any
#     other $ID instead of silently no-opping.
#
# trust-server itself shells out to openssl s_client, sudo, and
# update-ca-* — none of which we can or should run from bats. So the
# dynamic tests here extract the post-FQDN-parse `case $ID in ... esac`
# block from the live script with awk and source it under a controlled
# environment with stubbed add-certs-amzn / add-certs-ubuntu.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  TARGET="$REPO_ROOT/bash/trust-server"
  export TARGET
}

# Helper: extract the dispatch case statement from the live script and
# source it under the given $ID with stubbed dispatch helpers. The stub
# helpers echo a marker so callers can grep $output for the expected
# arm.
run_dispatch() {
  local id=$1
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include error
    @include log
    add-certs-amzn() { echo \"AMZN_ARM:\$1\"; }
    add-certs-ubuntu() { echo \"UBUNTU_ARM:\$1\"; }
    ID='$id'
    _FQDN=test_example_com
    eval \"\$(awk '/^case \\\$ID in/,/^esac\$/' '$TARGET')\"
  "
}

@test "trust-server contains the /etc/os-release readability guard" {
  run grep -E "^\[ -r /etc/os-release \] \|\| error::exit" "$TARGET"
  [ "$status" -eq 0 ]
}

@test "trust-server os-release guard fails with the documented error" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include error
    @include log
    [ -r '/non/existent/os-release' ] || error::exit \\
      'trust-server: /etc/os-release not found; cannot determine distro'
  "
  [ "$status" -ne 0 ]
  [[ "$output" == *"/etc/os-release not found"* ]]
}

@test "trust-server case dispatch: unsupported \$ID hits default arm error" {
  run_dispatch nixos
  [ "$status" -ne 0 ]
  [[ "$output" == *"unsupported distro 'nixos'"* ]]
}

@test "trust-server case dispatch: amzn -> add-certs-amzn" {
  run_dispatch amzn
  [ "$status" -eq 0 ]
  [[ "$output" == *"AMZN_ARM:test_example_com.pem"* ]]
}

@test "trust-server case dispatch: ubuntu -> add-certs-ubuntu" {
  run_dispatch ubuntu
  [ "$status" -eq 0 ]
  [[ "$output" == *"UBUNTU_ARM:test_example_com.pem"* ]]
}

@test "trust-server case dispatch: debian -> add-certs-ubuntu" {
  run_dispatch debian
  [ "$status" -eq 0 ]
  [[ "$output" == *"UBUNTU_ARM:test_example_com.pem"* ]]
}

@test "trust-server case dispatch: fedora -> add-certs-amzn" {
  run_dispatch fedora
  [ "$status" -eq 0 ]
  [[ "$output" == *"AMZN_ARM:test_example_com.pem"* ]]
}

@test "trust-server case dispatch: rhel -> add-certs-amzn" {
  run_dispatch rhel
  [ "$status" -eq 0 ]
  [[ "$output" == *"AMZN_ARM:test_example_com.pem"* ]]
}
