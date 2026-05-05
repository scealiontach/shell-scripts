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

@test "options help SYNTAX line names the entry script under -h dispatch (SUR-1926)" {
  # Regression for SUR-1926: BASH_SOURCE[2] resolves to options.sh itself
  # when -h is dispatched through OPTIONS_PARSE_FUNCS (one frame deeper
  # than the no-args path). BASH_SOURCE[-1] always resolves to the entry
  # script regardless of dispatch depth.
  run bash "$REPO_ROOT/tests/fixtures/sur-1926-help.sh" -h
  [ "$status" -ne 0 ]
  # The SYNTAX line should name the fixture, not options.sh.
  [[ "$output" == *"sur-1926-help.sh"* ]]
  [[ "$output" != *"options.sh ["* ]]
}

@test "options help SYNTAX line names the entry script on no-args path (SUR-1926)" {
  # The no-args path also runs through options::syntax_exit. Verify both
  # dispatch paths report the same script name.
  run bash "$REPO_ROOT/tests/fixtures/sur-1926-help.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"sur-1926-help.sh"* ]]
  [[ "$output" != *"options.sh ["* ]]
}

@test "options::add walks all args even when an arg is empty (SUR-1940)" {
  # Forward-looking invariant for SUR-1940. The old `while [ -n \"\$1\" ]`
  # guard conflates "no more args" with "next arg is empty"; no current
  # caller exercised a sequence where \$1 became "" mid-loop, so this
  # assertion would have passed under the old code too. Locking the
  # invariant prevents future callers from regressing into the buggy
  # idiom by relying on the structurally-correct `[ \"\$#\" -gt 0 ]`.
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

@test "options::parse_available fails when mandatory -m option is absent (SUR-2322)" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include options
    options::clear
    options::add -o l -d 'label' -a -m -e LabelSelector
    NO_SYNTAX_EXIT=1 options::parse_available
  "
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing required option"* ]] || [[ "$output" == *"-l"* ]]
}

@test "options::parse_available fails when mandatory option argument is empty (SUR-2322)" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include options
    options::clear
    options::add -o l -d 'label' -a -m -e LabelSelector
    NO_SYNTAX_EXIT=1 options::parse_available -l ''
  "
  [ "$status" -ne 0 ]
  [[ "$output" == *"empty"* ]] || [[ "$output" == *"-l"* ]]
}
