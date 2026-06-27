#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRESERVER="$ROOT_DIR/script/preserve_release_failure_artifacts.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/minddesk-release-failure-artifacts.XXXXXX")"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  echo "$1" >&2
  exit 1
}

assert_file_contains() {
  local file="$1"
  local expected="$2"
  [[ -f "$file" ]] || fail "Missing expected file: $file"
  grep -Fq "$expected" "$file" || fail "$file must contain: $expected"
}

assert_status() {
  local expected_status="$1"
  shift
  local output
  set +e
  output="$(bash "$PRESERVER" "$@" 2>&1)"
  local actual_status=$?
  set -e
  if [[ "$actual_status" -ne "$expected_status" ]]; then
    printf '%s\n' "$output" >&2
    fail "Expected status $expected_status, got $actual_status"
  fi
}

release_root="$TMP_ROOT/dist/release"
artifact_dir="$TMP_ROOT/.staging-release/artifacts"
release_name="MindDesk-v1.2.3-macOS"
mkdir -p "$artifact_dir"
printf '{"status":"Invalid"}\n' >"$artifact_dir/notary-submit-dmg.json"
printf 'Authority=Developer ID Application: Qiushan Huang (TEAMID)\n' >"$artifact_dir/codesign-dmg.txt"

output="$(
  bash "$PRESERVER" \
    --artifact-dir "$artifact_dir" \
    --release-root "$release_root" \
    --release-name "$release_name"
)"

preserved_dir="$release_root/$release_name-failed-artifacts/artifacts"
[[ "$output" == *"$preserved_dir"* ]] || fail "Expected output to include preserved directory"
assert_file_contains "$preserved_dir/notary-submit-dmg.json" "Invalid"
assert_file_contains "$preserved_dir/codesign-dmg.txt" "Developer ID Application"

printf 'existing\n' >"$preserved_dir/existing.txt"
second_output="$(
  bash "$PRESERVER" \
    --artifact-dir "$artifact_dir" \
    --release-root "$release_root" \
    --release-name "$release_name"
)"
second_dir="$release_root/$release_name-failed-artifacts-2/artifacts"
[[ "$second_output" == *"$second_dir"* ]] || fail "Expected second output to include unique preserved directory"
assert_file_contains "$second_dir/notary-submit-dmg.json" "Invalid"
assert_file_contains "$preserved_dir/existing.txt" "existing"

missing_output="$(
  bash "$PRESERVER" \
    --artifact-dir "$TMP_ROOT/missing/artifacts" \
    --release-root "$release_root" \
    --release-name "$release_name"
)"
[[ -z "$missing_output" ]] || fail "Missing artifact directory should not produce output"

assert_status 2 --unknown-option

echo "Release failure artifact preserver tests passed."
