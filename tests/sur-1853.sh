#!/usr/bin/env bash
# SUR-1853: lock down the structural shape of the new GitHub Actions CI
# pipeline so a future edit cannot silently break the pieces the legacy
# Jenkinsfile relied on.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"

CI_YAML="$REPO_ROOT/.github/workflows/ci.yaml"
PRECOMMIT_YAML="$REPO_ROOT/.github/workflows/pre-commit.yaml"

failures=0

# 1. The new workflow must exist.
if [ ! -f "$CI_YAML" ]; then
  echo "FAIL: $CI_YAML missing" >&2
  failures=$((failures + 1))
fi

# 2. The pre-commit workflow must still exist (and stay separate).
if [ ! -f "$PRECOMMIT_YAML" ]; then
  echo "FAIL: $PRECOMMIT_YAML missing — pre-commit pipeline removed" >&2
  failures=$((failures + 1))
fi

# 3. The Jenkinsfile must be gone.
if [ -e "$REPO_ROOT/Jenkinsfile" ]; then
  echo "FAIL: Jenkinsfile is still present" >&2
  failures=$((failures + 1))
fi

# Below assertions only make sense if the CI yaml exists.
if [ -f "$CI_YAML" ]; then
  # 4. checkout step must request full history and tags so `make
  #    what_version` works (mirrors the Jenkinsfile's bespoke fetch).
  if ! grep -q 'fetch-depth: 0' "$CI_YAML"; then
    echo "FAIL: ci.yaml missing 'fetch-depth: 0'" >&2
    failures=$((failures + 1))
  fi
  if ! grep -q 'fetch-tags: true' "$CI_YAML"; then
    echo "FAIL: ci.yaml missing 'fetch-tags: true'" >&2
    failures=$((failures + 1))
  fi

  # 5. analyze step must be gated on FOSSA_API_KEY so PRs from forks
  #    succeed even without the secret.
  if ! grep -q "env.FOSSA_API_KEY != ''" "$CI_YAML"; then
    echo "FAIL: ci.yaml missing FOSSA_API_KEY gate" >&2
    failures=$((failures + 1))
  fi

  # 6. publish job must be gated on push to main or tag — never on PR.
  #    The `if:` condition lives across multiple lines (yamllint folded
  #    scalar), so search for the union of phrases instead.
  if ! grep -q "refs/heads/main" "$CI_YAML"; then
    echo "FAIL: ci.yaml publish gate does not reference refs/heads/main" >&2
    failures=$((failures + 1))
  fi
  if ! grep -q "refs/tags/" "$CI_YAML"; then
    echo "FAIL: ci.yaml publish gate does not reference refs/tags/" >&2
    failures=$((failures + 1))
  fi

  # 7. publish must use GITHUB_TOKEN, not Jenkins-managed credentials.
  # shellcheck disable=SC2016 # ${{ ... }} is GHA-template syntax, not bash.
  if ! grep -q 'GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}' "$CI_YAML"; then
    echo "FAIL: ci.yaml publish step missing GITHUB_TOKEN env" >&2
    failures=$((failures + 1))
  fi

  # 8. Must call the four core targets that mirror the Jenkins stages.
  for target in 'make clean build' 'make package' 'make test' 'make archive'; do
    if ! grep -q "$target" "$CI_YAML"; then
      echo "FAIL: ci.yaml missing '$target' step" >&2
      failures=$((failures + 1))
    fi
  done

  # 9. Must upload artifacts for non-publish runs (PRs / non-main pushes).
  if ! grep -q 'actions/upload-artifact' "$CI_YAML"; then
    echo "FAIL: ci.yaml does not upload build artifacts" >&2
    failures=$((failures + 1))
  fi
fi

# 10. AGENTS.md should no longer claim "Jenkins runs ..."
if grep -q 'Jenkins runs' "$REPO_ROOT/AGENTS.md"; then
  echo "FAIL: AGENTS.md still references 'Jenkins runs'" >&2
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  echo "sur-1853: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
