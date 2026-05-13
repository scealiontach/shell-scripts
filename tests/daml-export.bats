#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# SUR-2838: direct helper-level coverage for bash/daml-export.
# Complements (does not replace) the end-to-end SUR-1871 regression
# under tests/sur-1871-daml-export.sh; this spec exercises the
# documented contract points in isolation:
#
#   1. hex_to_dec / dec_to_hex round-trip and padding.
#   2. verifyExport three-state return code.
#   3. correct_archives sed rewrite + idempotency.
#   4. correct_export dual-file rewrite (daml.yaml + Export.daml).
#
# Uses the DAML_EXPORT_SOURCE_ONLY guard added in this sprint to source
# the script without firing the main offset-walking loop. Test bodies
# run inside `bash -c` to keep bats' `set -e` from tripping on the
# trailing `&&` in `options::add` when sourced helpers are defined.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  DAML_EXPORT="$REPO_ROOT/bash/daml-export"
  export LOGFILE_DISABLE=true LOG_DISABLE_DEBUG=true LOG_DISABLE_INFO=true
  export DAML_EXPORT_SOURCE_ONLY=true
}

@test "DAML_EXPORT_SOURCE_ONLY exits 0 when executed (no main body) (SUR-2838)" {
  out=$(mktemp -d)
  run env DAML_EXPORT_SOURCE_ONLY=true bash "$DAML_EXPORT" -d "$out" -e ffff
  rm -rf "$out"
  [ "$status" -eq 0 ]
  # The main loop's "Exporting from offset" log lines must not appear.
  [[ "$output" != *"Exporting from offset"* ]]
}

@test "hex_to_dec converts hex strings to decimal (SUR-2838 case 1)" {
  tmp=$(mktemp -d)
  run bash -c "
    source '$DAML_EXPORT' -d '$tmp' -e ffff
    printf '%s|%s|%s\n' \"\$(hex_to_dec 0a)\" \"\$(hex_to_dec 0)\" \"\$(hex_to_dec ff)\"
  "
  rm -rf "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == *"10|0|255"* ]]
}

@test "dec_to_hex pads to 16 hex chars (SUR-2838 case 2)" {
  tmp=$(mktemp -d)
  run bash -c "
    source '$DAML_EXPORT' -d '$tmp' -e ffff
    printf '%s|%s|%s\n' \"\$(dec_to_hex 10)\" \"\$(dec_to_hex 0)\" \"\$(dec_to_hex 65535)\"
  "
  rm -rf "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == *"000000000000000a|0000000000000000|000000000000ffff"* ]]
}

@test "verifyExport returns 2 for an empty directory (SUR-2838 case 3)" {
  tmp=$(mktemp -d)
  run bash -c "
    source '$DAML_EXPORT' -d '$tmp' -e ffff
    verifyExport '$tmp'
    echo rc=\$?
  "
  rm -rf "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == *"rc=2"* ]]
}

@test "verifyExport returns 2 when export.good missing (SUR-2838 case 3)" {
  tmp=$(mktemp -d)
  touch "$tmp/Export.daml"
  run bash -c "
    source '$DAML_EXPORT' -d '$tmp' -e ffff
    verifyExport '$tmp'
    echo rc=\$?
  "
  rm -rf "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == *"rc=2"* ]]
}

@test "verifyExport returns 1 when export.good + Export.daml present but no dar (SUR-2838 case 3)" {
  tmp=$(mktemp -d)
  touch "$tmp/export.good" "$tmp/Export.daml"
  run bash -c "
    source '$DAML_EXPORT' -d '$tmp' -e ffff
    verifyExport '$tmp'
    echo rc=\$?
  "
  rm -rf "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == *"rc=1"* ]]
}

@test "verifyExport returns 0 when export.good + Export.daml + dar all present (SUR-2838 case 3)" {
  tmp=$(mktemp -d)
  touch "$tmp/export.good" "$tmp/Export.daml"
  mkdir -p "$tmp/.daml/dist"
  touch "$tmp/.daml/dist/export-1.0.0.dar"
  run bash -c "
    source '$DAML_EXPORT' -d '$tmp' -e ffff
    verifyExport '$tmp'
    echo rc=\$?
  "
  rm -rf "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == *"rc=0"* ]]
}

@test "correct_archives rewrites exerciseCmd … DA.Internal.Template.Archive to archiveCmd (SUR-2838 case 4)" {
  tmp=$(mktemp -d)
  cat >"$tmp/Export.daml" <<'EOF'
exerciseCmd foo DA.Internal.Template.Archive
exerciseCmd bar DA.Internal.Template.Archive
something else entirely
EOF
  run bash -c "
    source '$DAML_EXPORT' -d '$tmp' -e ffff
    correct_archives '$tmp'
  "
  [ "$status" -eq 0 ]
  grep -q "^archiveCmd foo$" "$tmp/Export.daml"
  grep -q "^archiveCmd bar$" "$tmp/Export.daml"
  grep -q "^something else entirely$" "$tmp/Export.daml"
  run ! grep -q "DA.Internal.Template.Archive" "$tmp/Export.daml"
  rm -rf "$tmp"
}

@test "correct_archives is idempotent on a second invocation (SUR-2838 case 4)" {
  tmp=$(mktemp -d)
  cat >"$tmp/Export.daml" <<'EOF'
exerciseCmd foo DA.Internal.Template.Archive
EOF
  run bash -c "
    source '$DAML_EXPORT' -d '$tmp' -e ffff
    correct_archives '$tmp'
    sum1=\$(cksum '$tmp/Export.daml')
    correct_archives '$tmp'
    sum2=\$(cksum '$tmp/Export.daml')
    [ \"\$sum1\" = \"\$sum2\" ] && echo SAME || echo DIFFERENT
  "
  rm -rf "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SAME"* ]]
}

@test "correct_export rewrites both daml.yaml and Export.daml (SUR-2838 case 5)" {
  tmp=$(mktemp -d)
  cat >"$tmp/daml.yaml" <<'EOF'
sdk-version: 1.13.1
build-options: ["--target=1.14"]
EOF
  cat >"$tmp/Export.daml" <<'EOF'
import qualified DA.Internal.Template
exerciseCmd foo DA.Internal.Template.Archive
EOF
  run bash -c "
    source '$DAML_EXPORT' -d '$tmp' -e ffff >/dev/null
    correct_export '$tmp' >/dev/null
  "
  [ "$status" -eq 0 ]
  grep -q "build-options: \[\"--target=1.12\"\]" "$tmp/daml.yaml"
  run ! grep -q "import qualified DA.Internal.Template$" "$tmp/Export.daml"
  grep -q "^archiveCmd foo$" "$tmp/Export.daml"
  rm -rf "$tmp"
}
