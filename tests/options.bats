#!/usr/bin/env bats
# SUR-1850 seed: options::add / options::parse contracts.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
}

@test "options::add -e exports the optarg into the named global" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include options
    options::clear
    options::add -o f -d 'input file' -a -e InputFile
    options::parse_available -f /tmp/example.txt
    echo \"InputFile=\$InputFile\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"InputFile=/tmp/example.txt"* ]]
}

@test "options::add -x flips the named global to true when present" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include options
    options::clear
    options::add -o x -d 'dry run' -x DryRun
    options::parse_available -x
    echo \"DryRun=\$DryRun\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"DryRun=true"* ]]
}

@test "options::parse exits non-zero with no args (no NO_SYNTAX_EXIT)" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include options
    options::clear
    options::add -o f -d 'input file' -a -e InputFile
    options::parse
  "
  [ "$status" -ne 0 ]
}
