#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$ROOT_DIR/script/verify_release_worktree.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/minddesk-release-guard.XXXXXX")"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  echo "$1" >&2
  exit 1
}

make_repo() {
  local name="$1"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo/Sources/App" "$repo/Tests/AppTests" "$repo/script" "$repo/docs" "$repo/.github/workflows"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Release Guard Test"
  cat >"$repo/.gitignore" <<'GITIGNORE'
.build/
dist/
GITIGNORE
  printf 'print("hello")\n' >"$repo/Sources/App/main.swift"
  printf 'test\n' >"$repo/Tests/AppTests/AppTests.swift"
  printf '#!/usr/bin/env bash\n' >"$repo/script/package_release.sh"
  printf '# Test\n' >"$repo/docs/feature-checklist.md"
  printf 'name: ci\n' >"$repo/.github/workflows/ci.yml"
  printf '// swift-tools-version: 6.0\n' >"$repo/Package.swift"
  git -C "$repo" add .
  git -C "$repo" commit -q -m "fixture"
  printf '%s\n' "$repo"
}

assert_passes() {
  local repo="$1"
  local output
  if ! output="$("$GUARD" --root "$repo" 2>&1)"; then
    printf '%s\n' "$output" >&2
    fail "Expected release worktree guard to pass for $repo"
  fi
}

assert_fails_with() {
  local repo="$1"
  local expected="$2"
  local output
  if output="$("$GUARD" --root "$repo" 2>&1)"; then
    printf '%s\n' "$output" >&2
    fail "Expected release worktree guard to fail for $repo"
  fi
  grep -Fq "$expected" <<<"$output" || {
    printf '%s\n' "$output" >&2
    fail "Expected guard output to contain: $expected"
  }
}

assert_fails_with_all() {
  local repo="$1"
  shift
  local output
  if output="$("$GUARD" --root "$repo" 2>&1)"; then
    printf '%s\n' "$output" >&2
    fail "Expected release worktree guard to fail for $repo"
  fi
  for expected in "$@"; do
    grep -Fq "$expected" <<<"$output" || {
      printf '%s\n' "$output" >&2
      fail "Expected guard output to contain: $expected"
    }
  done
}

assert_status() {
  local expected_status="$1"
  shift
  local output
  set +e
  output="$("$@" 2>&1)"
  local actual_status=$?
  set -e
  if [[ "$actual_status" -ne "$expected_status" ]]; then
    printf '%s\n' "$output" >&2
    fail "Expected status $expected_status, got $actual_status for command: $*"
  fi
}

clean_repo="$(make_repo clean)"
assert_passes "$clean_repo"

untracked_repo="$(make_repo untracked-critical)"
printf 'struct NewFeature {}\n' >"$untracked_repo/Sources/App/NewFeature.swift"
assert_fails_with "$untracked_repo" "Untracked release-critical files"

untracked_noncritical_repo="$(make_repo untracked-noncritical)"
printf 'local notes\n' >"$untracked_noncritical_repo/notes.local.md"
assert_passes "$untracked_noncritical_repo"

ignored_repo="$(make_repo ignored-build)"
mkdir -p "$ignored_repo/.build/debug"
printf 'ignored\n' >"$ignored_repo/.build/debug/object.o"
assert_passes "$ignored_repo"

ignored_dist_repo="$(make_repo ignored-dist)"
mkdir -p "$ignored_dist_repo/dist/release"
printf 'ignored\n' >"$ignored_dist_repo/dist/release/artifact.dmg"
assert_passes "$ignored_dist_repo"

ignored_critical_repo="$(make_repo ignored-critical)"
printf 'Sources/App/Generated.swift\n' >>"$ignored_critical_repo/.gitignore"
git -C "$ignored_critical_repo" add .gitignore
git -C "$ignored_critical_repo" commit -q -m "ignore generated source"
printf 'struct Generated {}\n' >"$ignored_critical_repo/Sources/App/Generated.swift"
assert_fails_with_all \
  "$ignored_critical_repo" \
  "Ignored release-critical files must be added or removed before release" \
  "Sources/App/Generated.swift"

dirty_repo="$(make_repo dirty-tracked)"
printf 'print("changed")\n' >>"$dirty_repo/Sources/App/main.swift"
assert_fails_with "$dirty_repo" "Tracked release-critical changes"

staged_repo="$(make_repo staged-tracked)"
printf 'test changed\n' >>"$staged_repo/Tests/AppTests/AppTests.swift"
git -C "$staged_repo" add Tests/AppTests/AppTests.swift
assert_fails_with "$staged_repo" "Tracked release-critical changes"

combined_repo="$(make_repo combined-tracked-untracked)"
printf 'print("changed")\n' >>"$combined_repo/Sources/App/main.swift"
printf 'struct Extra {}\n' >"$combined_repo/Sources/App/Extra.swift"
assert_fails_with_all \
  "$combined_repo" \
  "Tracked release-critical changes" \
  "Sources/App/main.swift" \
  "Untracked release-critical files" \
  "Sources/App/Extra.swift"

non_git_dir="$TMP_ROOT/not-git"
mkdir -p "$non_git_dir"
assert_status 3 "$GUARD" --root "$non_git_dir"
assert_status 2 "$GUARD" --unknown-option

echo "Release worktree guard tests passed."
