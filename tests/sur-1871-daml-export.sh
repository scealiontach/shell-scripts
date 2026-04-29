#!/usr/bin/env bash
# SUR-1871: bash/daml-export
#   1. Variable hygiene: `ret=$?` inside `build()` must be local.
#   2. Loop guard: rewrite of the brittle
#      `[ "$CUR_INT" != "$NEXT_INT" ]` guard must traverse all ranges
#      between START_OFFSET and STOP_OFFSET in STEPPING-sized chunks
#      and terminate cleanly without producing empty-range artifacts.
#   3. TO_BUILD removal: equivalent behaviour preserved through the
#      post-loop `find ... export.good` walk.
#
# This script stands up PATH-shadowed `java` and `daml` stubs and runs
# the binary against a 3-range export (offsets 0 → 0x5dc, stepping 500),
# asserting that exactly three `export.good` artifacts surface.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

failures=0
script="$REPO_ROOT/bash/daml-export"

# 1. Static check: the `ret=$?` site inside `build()` must declare local ret.
if ! awk '/^function build /,/^}$/' "$script" | grep -q 'local ret'; then
  echo "FAIL: bash/daml-export build() does not declare 'local ret'" >&2
  failures=$((failures + 1))
fi

# 2. Static check: TO_BUILD assignments and the brittle
#    `[ "$CUR_INT" != "$NEXT_INT" ]` guard must be gone.
if grep -q 'TO_BUILD=\|TO_BUILD+=' "$script"; then
  echo "FAIL: TO_BUILD references still present in bash/daml-export" >&2
  failures=$((failures + 1))
fi
# shellcheck disable=SC2016 # we are grepping for the literal $CUR_INT / $NEXT_INT
if grep -vE '^[[:space:]]*#' "$script" | grep -q '"\$CUR_INT" != "\$NEXT_INT"'; then
  echo "FAIL: brittle CUR_INT/NEXT_INT guard still present (non-comment)" >&2
  failures=$((failures + 1))
fi

# 3. Static check (SUR-1883): post-loop walk must use process substitution so
#    RUNNING_PROCS mutations are visible in the parent shell.
if ! grep -q '< <(' "$script"; then
  echo "FAIL: post-loop walk does not use process substitution (< <(...))" >&2
  failures=$((failures + 1))
fi

# 4. Static check (SUR-1883): verify_and_build function must exist (extracts
#    the bare ret=$? site out of the subshell and into a function with local ret).
if ! grep -q 'function verify_and_build' "$script"; then
  echo "FAIL: verify_and_build function not found in bash/daml-export" >&2
  failures=$((failures + 1))
fi

# 5. Static check (SUR-1883): no bare ret=$? anywhere in the script
#    (all sites must use 'local ret=$?' or be refactored to if/if ! form).
if grep -vE '^[[:space:]]*#' "$script" | grep 'ret=\$?' | grep -qv 'local ret=\$?'; then
  echo "FAIL: bare ret=\$? still present in bash/daml-export (must be local ret=\$?)" >&2
  failures=$((failures + 1))
fi

# 6. End-to-end check: stub java + daml on PATH, run the script, count
#    export.good artefacts.
tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT
HOME_DIR="$tmp_root/home"
stub_dir="$tmp_root/bin"
target_dir="$tmp_root/target"
mkdir -p "$HOME_DIR" "$stub_dir" "$target_dir"

cat >"$stub_dir/java" <<'STUB_EOF'
#!/usr/bin/env bash
# Resolve the -o output dir from argv and lay down the files that
# daml-export's correct_export step expects.
output_dir=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "-o" ]; then
    output_dir="$arg"
    break
  fi
  prev="$arg"
done
if [ -z "$output_dir" ]; then
  echo "java stub: no -o arg in: $*" >&2
  exit 1
fi
mkdir -p "$output_dir/.daml/dist"
echo "name: fake-export" >"$output_dir/daml.yaml"
echo "version: 0.0.1 --target=1.14" >>"$output_dir/daml.yaml"
echo "import qualified DA.Internal.Template" >"$output_dir/Export.daml"
echo "main = pure ()" >>"$output_dir/Export.daml"
exit 0
STUB_EOF
chmod +x "$stub_dir/java"

cat >"$stub_dir/daml" <<'STUB_EOF'
#!/usr/bin/env bash
# `daml build` is invoked from inside OUTPUT_DIR; create the dar in
# place so verifyExport returns 0 on the post-loop pass.
mkdir -p .daml/dist
touch .daml/dist/export-1.0.0.dar
exit 0
STUB_EOF
chmod +x "$stub_dir/daml"

# Run with START=0, STOP=0x5dc (1500), STEPPING=500, MAX_PARALLEL=5 so
# all three in-loop builds slot in concurrently. Background-exec with a
# wall-clock timeout to detect regressions that re-introduce a hang.
(
  HOME="$HOME_DIR"
  PATH="$stub_dir:$PATH"
  export HOME PATH
  bash "$script" \
    -d "$target_dir" \
    -b "0000000000000000" \
    -e "00000000000005dc" \
    -s 500 \
    -P 5
) >"$tmp_root/run.log" 2>&1 &
script_pid=$!

elapsed=0
limit=30
while kill -0 "$script_pid" 2>/dev/null; do
  sleep 1
  elapsed=$((elapsed + 1))
  if [ "$elapsed" -ge "$limit" ]; then
    kill -9 "$script_pid" 2>/dev/null
    echo "FAIL: daml-export did not terminate within ${limit}s (loop hang?)" >&2
    cat "$tmp_root/run.log" >&2
    failures=$((failures + 1))
    break
  fi
done

if [ "$elapsed" -lt "$limit" ]; then
  wait "$script_pid"
  script_rc=$?
  if [ "$script_rc" -ne 0 ]; then
    echo "FAIL: daml-export exited rc=$script_rc" >&2
    cat "$tmp_root/run.log" >&2
    failures=$((failures + 1))
  fi
fi

# Three ranges should produce three export.good markers.
mapfile -t good_files < <(find "$target_dir" -name 'export.good' | sort)
if [ "${#good_files[@]}" -ne 3 ]; then
  echo "FAIL: expected 3 export.good markers, found ${#good_files[@]}" >&2
  printf '  %s\n' "${good_files[@]}" >&2
  failures=$((failures + 1))
fi

# And the dirs must match the expected hex-range layout: 0->1f4,
# 1f4->3e8, 3e8->5dc.
for hex_pair in \
  "0000000000000000-00000000000001f4" \
  "00000000000001f4-00000000000003e8" \
  "00000000000003e8-00000000000005dc"; do
  if [ ! -r "$target_dir/$hex_pair/export.good" ]; then
    echo "FAIL: missing export.good for range $hex_pair" >&2
    failures=$((failures + 1))
  fi
done

# Behavioral check (SUR-1883 DoD: RUNNING_PROCS populated after post-loop walk).
#
# Direct inspection of RUNNING_PROCS from outside the script subprocess is not
# feasible — the array lives in the script's own shell and is not exported.
# Instead we verify the dar output files that the background 'daml build'
# processes (tracked via RUNNING_PROCS) are responsible for producing.  If
# process substitution is absent (pipe subshell used instead), RUNNING_PROCS
# mutations are lost in the parent and the kill_running_procs trap silently
# fires on zero pids; builds may still complete due to background &, but the
# parent loses awareness of them.  The static check above (< <(...)) catches
# the structural regression; this check verifies the builds actually ran.
for hex_pair in \
  "0000000000000000-00000000000001f4" \
  "00000000000001f4-00000000000003e8" \
  "00000000000003e8-00000000000005dc"; do
  if [ ! -f "$target_dir/$hex_pair/.daml/dist/export-1.0.0.dar" ]; then
    echo "FAIL: missing .daml/dist/export-1.0.0.dar for range $hex_pair (build did not run)" >&2
    failures=$((failures + 1))
  fi
done

# No empty-range stray artefact (CUR==NEXT after capping).
if [ -e "$target_dir/00000000000005dc-00000000000005dc" ]; then
  echo "FAIL: empty-range artefact 5dc-5dc was created" >&2
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  echo "sur-1871: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
