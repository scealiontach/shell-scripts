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

@test "options::add walks all args even when an arg is empty (SUR-1940)" {
  # Regression for SUR-1940: the old `while [ -n \"\$1\" ]` guard treated an
  # empty arg as end-of-args and silently dropped subsequent flags. With the
  # `\$# -gt 0` guard, an empty -d "" must not stop processing of the trailing
  # -m/-x flags.
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include options
    options::clear
    options::add -o a -d '' -m -x A
    options::add -o b -d 'B' -x B
    # Print a tab-separated dump of the registered options and their flags.
    for opt in \"\${OPTIONS[@]}\"; do
      printf '%s|optional=%s|env=%s\n' \
        \"\$opt\" \"\${OPTIONS_OPTIONAL[\$opt]}\" \"\${OPTIONS_ENVIRONMENT[\$opt]}\"
    done
  "
  [ "$status" -eq 0 ]
  # Both flags must be registered.
  [[ "$output" == *"a|optional=false|env=A"* ]]
  [[ "$output" == *"b|optional=true|env=B"* ]]
}
