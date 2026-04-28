#!/usr/bin/env bats
# SUR-1851: end-to-end coverage of bash/update-repo-tags driving bash/semver
# against a synthetic git repo. Specifically locks down the Xp1 prerel
# post-processing on lines 84-86 of update-repo-tags (replace -N with pN).

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  helpers::set_git_identity
  REPO=$(mktemp -d)
  # update-repo-tags hard-codes `git tag -a -s`, which requires a
  # configured GPG key. Tests run with a fresh tempdir HOME (no ~/.gnupg),
  # so wrap git on PATH with a trampoline that strips -s before delegating
  # to the real binary. This keeps the rest of the script behaviour intact
  # while letting the annotated tag actually be created.
  REAL_GIT=$(command -v git)
  STUB_BIN=$(mktemp -d)
  cat >"$STUB_BIN/git" <<EOF
#!/usr/bin/env bash
args=()
for a in "\$@"; do
  if [ "\$a" = "-s" ] || [ "\$a" = "--sign" ]; then
    continue
  fi
  args+=("\$a")
done
exec "$REAL_GIT" "\${args[@]}"
EOF
  chmod +x "$STUB_BIN/git"
  PATH="$STUB_BIN:$PATH"
  # Reset commands::use cache so the stub is picked up if any prior caller
  # had already resolved git.
  unset _git
  (cd "$REPO" && git init -q -b main . >/dev/null)
  UPDATE="$REPO_ROOT/bash/update-repo-tags"
  export REPO UPDATE STUB_BIN PATH
}

teardown() {
  rm -rf "$REPO" "$STUB_BIN"
}

# Helper: commit one file with the given message.
commit_msg() {
  local msg=$1 file=${2:-file}
  (
    cd "$REPO" &&
      date +%s%N >>"$file" &&
      git add "$file" &&
      git -c commit.gpgsign=false commit -q -m "$msg"
  )
}

# Helper: create an annotated tag at HEAD.
annotated_tag() {
  (cd "$REPO" && git tag -a -m "tag $1" "$1")
}

# Helper: lightweight (non-annotated) tag at HEAD.
light_tag() {
  (cd "$REPO" && git tag "$1")
}

# Helper: most recent tag in the repo.
latest_tag() {
  (cd "$REPO" && git describe --tags --abbrev=0 2>/dev/null)
}

@test "bumps patch from an annotated v0.1.0 with one feat: commit" {
  commit_msg "feat: initial"
  annotated_tag v0.1.0
  commit_msg "feat: another"
  run "$UPDATE" -t "$REPO"
  [ "$status" -eq 0 ]
  [ "$(latest_tag)" = "v0.1.1" ]
}

@test "Xp1 post-processing: lightweight tag triggers vN.N.NpN form" {
  commit_msg "feat: initial"
  # A *lightweight* tag — describe will find it via --tags, but
  # describe-without-tags returns no annotated tag, forcing the prerel path.
  light_tag v0.1.0
  commit_msg "fix: something"
  run "$UPDATE" -t "$REPO"
  [ "$status" -eq 0 ]
  # The Xp1 transform replaces "-1" with "p1": 0.1.0 + prerel 1 -> 0.1.0p1.
  [ "$(latest_tag)" = "v0.1.0p1" ]
}

@test "Xp1 post-processing: increments existing pN suffix" {
  commit_msg "feat: initial"
  light_tag v0.1.0p1
  commit_msg "fix: something"
  run "$UPDATE" -t "$REPO"
  [ "$status" -eq 0 ]
  [ "$(latest_tag)" = "v0.1.0p2" ]
}

@test "refuses to bump minor on breaking change without -b" {
  commit_msg "feat: initial"
  annotated_tag v0.1.0
  commit_msg "feat!: breaking"
  run "$UPDATE" -t "$REPO"
  [ "$status" -ne 0 ]
  # Tag must not have been created.
  [ "$(latest_tag)" = "v0.1.0" ]
}

@test "bumps minor on breaking change with -b" {
  commit_msg "feat: initial"
  annotated_tag v0.1.0
  commit_msg "feat!: breaking"
  run "$UPDATE" -t "$REPO" -b
  [ "$status" -eq 0 ]
  [ "$(latest_tag)" = "v0.2.0" ]
}

@test "no changes since latest tag => keeps same tag (no new tag created)" {
  commit_msg "feat: initial"
  annotated_tag v0.1.0
  run "$UPDATE" -t "$REPO"
  [ "$status" -eq 0 ]
  [ "$(latest_tag)" = "v0.1.0" ]
}

@test "no prior tag at all => defaults to v0.1.0 prerel path" {
  commit_msg "feat: initial"
  run "$UPDATE" -t "$REPO"
  [ "$status" -eq 0 ]
  # No prior tag -> LATEST_TAG=v0.1.0, ANNOTATE_TAG=false, prerel path
  # produces v0.1.0p1.
  [ "$(latest_tag)" = "v0.1.0p1" ]
}
