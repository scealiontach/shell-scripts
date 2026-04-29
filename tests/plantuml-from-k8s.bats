#!/usr/bin/env bats
# SUR-1867: lock down bash/plantuml-from-k8s — verify that getItems,
# getRs, and getChildren keep their working variables (`selector`,
# `select`/`selector_text`, `child`, `clean_child`) function-local so
# they cannot contaminate later invocations or shadow the bash builtin
# `select`.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  STUB_BIN=$(mktemp -d)
  KUBECTL_ARGV_LOG=$(mktemp)
  cat >"$STUB_BIN/kubectl" <<'STUB_EOF'
#!/usr/bin/env bash
# Per-invocation stub: record argv, then return controlled output for
# the queries plantuml-from-k8s makes.
echo "$@" >>"$KUBECTL_ARGV_LOG"
case "$*" in
  *"describe -n "*) echo "Selector: app=widget" ;;
esac
STUB_EOF
  chmod +x "$STUB_BIN/kubectl"
  PATH="$STUB_BIN:$PATH"
  unset _kubectl
  export STUB_BIN KUBECTL_ARGV_LOG PATH
}

teardown() {
  rm -rf "$STUB_BIN"
  rm -f "$KUBECTL_ARGV_LOG"
}

@test "getItems labelled call sets -l, unlabelled call after it does not" {
  run env \
    "PATH=$PATH" \
    "KUBECTL_ARGV_LOG=$KUBECTL_ARGV_LOG" \
    "PLANTUML_FROM_K8S_SOURCE_ONLY=true" \
    bash -c "
      source '$REPO_ROOT/bash/plantuml-from-k8s' -c test
      getItems ns-a pod app=foo >/dev/null
      getItems ns-b pod >/dev/null
    "
  [ "$status" -eq 0 ]
  first=$(sed -n '1p' "$KUBECTL_ARGV_LOG")
  second=$(sed -n '2p' "$KUBECTL_ARGV_LOG")
  [[ "$first" == *"-l app=foo"* ]]
  [[ "$second" != *"-l "* ]]
}

@test "getItems and getRs keep selector, child, clean_child function-local" {
  run env \
    "PATH=$PATH" \
    "KUBECTL_ARGV_LOG=$KUBECTL_ARGV_LOG" \
    "PLANTUML_FROM_K8S_SOURCE_ONLY=true" \
    bash -c "
      source '$REPO_ROOT/bash/plantuml-from-k8s' -c test
      getItems ns-a pod app=foo >/dev/null
      getRs ns-a app=foo >/dev/null
      getChildren deployment rs ns-a dep1 Deploy Rs _U >/dev/null
      [ -z \"\${selector_text:-}\" ] || { echo 'selector_text leaked' >&2; exit 1; }
      [ -z \"\${child:-}\" ]         || { echo 'child leaked' >&2; exit 1; }
      [ -z \"\${clean_child:-}\" ]   || { echo 'clean_child leaked' >&2; exit 1; }
      [ \"\${#selector[@]}\" -eq 0 ] || { echo 'selector leaked' >&2; exit 1; }
    "
  [ "$status" -eq 0 ]
}

@test "getChildren no longer uses the identifier 'select' (avoid shadowing builtin)" {
  # Source-time grep guard: the in-tree function body must not assign
  # to a bare 'select' variable. Anchoring on 'function getChildren' to
  # avoid matching unrelated lines.
  run grep -E '^[[:space:]]*select=' "$REPO_ROOT/bash/plantuml-from-k8s"
  [ "$status" -ne 0 ]
}
