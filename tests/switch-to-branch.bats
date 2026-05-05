#!/usr/bin/env bats
# SUR-1882: switch-to-branch checks out the target branch in every repo
# under HOME/git/ORG and leaves no unclean working trees.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  helpers::set_git_identity
  SWITCH="$REPO_ROOT/bash/switch-to-branch"

  mkdir -p "$HOME/git/myorg"
  for repo in repo1 repo2; do
    local dir="$HOME/git/myorg/$repo"
    git init -q -b main "$dir"
    (
      cd "$dir" || exit 1
      echo seed >"$dir/file"
      git add file
      git -c commit.gpgsign=false commit -q -m "feat: initial"
      git checkout -q -b feature/test
      git checkout -q main
    )
  done
  export SWITCH
}

@test "switch-to-branch switches both repos to the target branch" {
  run "$SWITCH" -o myorg -b feature/test
  [ "$status" -eq 0 ]
  branch1=$(git -C "$HOME/git/myorg/repo1" rev-parse --abbrev-ref HEAD)
  branch2=$(git -C "$HOME/git/myorg/repo2" rev-parse --abbrev-ref HEAD)
  [ "$branch1" = "feature/test" ]
  [ "$branch2" = "feature/test" ]
}

@test "switch-to-branch leaves repos with clean working trees" {
  run "$SWITCH" -o myorg -b feature/test
  [ "$status" -eq 0 ]
  [ -z "$(git -C "$HOME/git/myorg/repo1" status --porcelain)" ]
  [ -z "$(git -C "$HOME/git/myorg/repo2" status --porcelain)" ]
}

@test "switch-to-branch plain checkout failure is reported (SUR-2378)" {
  run "$SWITCH" -o myorg -b nonexistent-branch -v
  [ "$status" -eq 0 ]
  [[ "$output" == *"Failed to checkout branch nonexistent-branch"* ]]
}

@test "switch-to-branch plain checkout stderr is not swallowed (SUR-2378)" {
  run "$SWITCH" -o myorg -b nonexistent-branch -v
  [ "$status" -eq 0 ]
  [[ "$output" == *"pathspec"* || "$output" == *"did not match"* ]]
}

@test "switch-to-branch -n does not checkout existing branch when create fails (SUR-2334)" {
  git -C "$HOME/git/myorg/repo1" branch -f sur2334-newb main >/dev/null
  run "$SWITCH" -o myorg -n -b sur2334-newb -v
  [ "$status" -eq 0 ]
  branch1=$(git -C "$HOME/git/myorg/repo1" rev-parse --abbrev-ref HEAD)
  [ "$branch1" = "main" ]
  [[ "$output" == *"Failed to create new branch sur2334-newb"* ]]
  [ ! -f "$HOME/git/myorg/repo1/exec.log" ]
  [ ! -f "$HOME/git/myorg/repo2/exec.log" ]
}
