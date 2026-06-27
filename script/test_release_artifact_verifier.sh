#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERIFIER="$ROOT_DIR/script/verify_release_artifacts.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/minddesk-release-artifacts.XXXXXX")"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  echo "$1" >&2
  exit 1
}

artifact_name() {
  local version="$1"
  local suffix="$2"
  local mode="$3"
  local name="MindDesk-v$version-$suffix"
  if [[ "$mode" == "adhoc" ]]; then
    name="$name-adhoc"
  fi
  printf '%s\n' "$name"
}

make_artifacts() {
  local fixture="$1"
  local version="$2"
  local suffix="$3"
  local mode="$4"
  local name
  local dir="$TMP_ROOT/$fixture"
  name="$(artifact_name "$version" "$suffix" "$mode")"

  mkdir -p "$dir"
  printf 'zip payload\n' >"$dir/$name.zip"
  printf 'dmg payload\n' >"$dir/$name.dmg"
  printf 'install notes\n' >"$dir/INSTALL.txt"
  printf '# Release notes\n' >"$dir/RELEASE-NOTES.md"
  (
    cd "$dir"
    shasum -a 256 "$name.zip" "$name.dmg" >"SHA256SUMS.txt"
  )
  printf '%s\n' "$dir"
}

write_notarized_evidence() {
  local dir="$1"
  cat >"$dir/notary-submit-app.json" <<'JSON'
{"id":"app-submission-id","status":"Accepted"}
JSON
  cat >"$dir/notary-submit-dmg.json" <<'JSON'
{"id":"dmg-submission-id","status":"Accepted"}
JSON
  cat >"$dir/codesign-app.txt" <<'TXT'
Authority=Developer ID Application: Qiushan Huang (TEAMID)
TeamIdentifier=TEAMID
Runtime Version=14.0.0
TXT
  cat >"$dir/codesign-dmg.txt" <<'TXT'
Authority=Developer ID Application: Qiushan Huang (TEAMID)
TeamIdentifier=TEAMID
TXT
  cat >"$dir/codesign-entitlements-app.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
PLIST
}

assert_passes() {
  local output
  if ! output="$(bash "$VERIFIER" "$@" 2>&1)"; then
    printf '%s\n' "$output" >&2
    fail "Expected release artifact verifier to pass"
  fi
}

assert_fails_with() {
  local expected="$1"
  shift
  local output
  if output="$(bash "$VERIFIER" "$@" 2>&1)"; then
    printf '%s\n' "$output" >&2
    fail "Expected release artifact verifier to fail"
  fi
  grep -Fq "$expected" <<<"$output" || {
    printf '%s\n' "$output" >&2
    fail "Expected verifier output to contain: $expected"
  }
}

assert_status() {
  local expected_status="$1"
  shift
  local output
  set +e
  output="$(bash "$VERIFIER" "$@" 2>&1)"
  local actual_status=$?
  set -e
  if [[ "$actual_status" -ne "$expected_status" ]]; then
    printf '%s\n' "$output" >&2
    fail "Expected status $expected_status, got $actual_status"
  fi
}

version="1.2.3"
suffix="ci-arm64"
mode="adhoc"
release_name="$(artifact_name "$version" "$suffix" "$mode")"

valid_dir="$(make_artifacts valid "$version" "$suffix" "$mode")"
assert_passes \
  --artifact-dir "$valid_dir" \
  --version "$version" \
  --suffix "$suffix" \
  --mode "$mode"

missing_zip_dir="$(make_artifacts missing-zip "$version" "$suffix" "$mode")"
rm "$missing_zip_dir/$release_name.zip"
assert_fails_with \
  "Missing required artifact" \
  --artifact-dir "$missing_zip_dir" \
  --version "$version" \
  --suffix "$suffix" \
  --mode "$mode"

corrupt_checksum_dir="$(make_artifacts corrupt-checksum "$version" "$suffix" "$mode")"
printf 'changed\n' >>"$corrupt_checksum_dir/$release_name.dmg"
assert_fails_with \
  "Checksum verification failed" \
  --artifact-dir "$corrupt_checksum_dir" \
  --version "$version" \
  --suffix "$suffix" \
  --mode "$mode"

notarized_mode="notarized"
notarized_release_name="$(artifact_name "$version" "$suffix" "$notarized_mode")"

valid_notarized_dir="$(make_artifacts valid-notarized "$version" "$suffix" "$notarized_mode")"
write_notarized_evidence "$valid_notarized_dir"
assert_passes \
  --artifact-dir "$valid_notarized_dir" \
  --version "$version" \
  --suffix "$suffix" \
  --mode "$notarized_mode"

missing_notary_dir="$(make_artifacts missing-notary "$version" "$suffix" "$notarized_mode")"
write_notarized_evidence "$missing_notary_dir"
rm "$missing_notary_dir/notary-submit-dmg.json"
assert_fails_with \
  "Missing required notarization evidence" \
  --artifact-dir "$missing_notary_dir" \
  --version "$version" \
  --suffix "$suffix" \
  --mode "$notarized_mode"

rejected_notary_dir="$(make_artifacts rejected-notary "$version" "$suffix" "$notarized_mode")"
write_notarized_evidence "$rejected_notary_dir"
cat >"$rejected_notary_dir/notary-submit-app.json" <<'JSON'
{"id":"app-submission-id","status":"Invalid"}
JSON
assert_fails_with \
  "Notarization was not accepted" \
  --artifact-dir "$rejected_notary_dir" \
  --version "$version" \
  --suffix "$suffix" \
  --mode "$notarized_mode"

missing_codesign_dir="$(make_artifacts missing-codesign "$version" "$suffix" "$notarized_mode")"
write_notarized_evidence "$missing_codesign_dir"
rm "$missing_codesign_dir/codesign-app.txt"
assert_fails_with \
  "Missing required codesign evidence" \
  --artifact-dir "$missing_codesign_dir" \
  --version "$version" \
  --suffix "$suffix" \
  --mode "$notarized_mode"

missing_dmg_codesign_dir="$(make_artifacts missing-dmg-codesign "$version" "$suffix" "$notarized_mode")"
write_notarized_evidence "$missing_dmg_codesign_dir"
rm "$missing_dmg_codesign_dir/codesign-dmg.txt"
assert_fails_with \
  "Missing required DMG codesign evidence" \
  --artifact-dir "$missing_dmg_codesign_dir" \
  --version "$version" \
  --suffix "$suffix" \
  --mode "$notarized_mode"

invalid_dmg_codesign_dir="$(make_artifacts invalid-dmg-codesign "$version" "$suffix" "$notarized_mode")"
write_notarized_evidence "$invalid_dmg_codesign_dir"
cat >"$invalid_dmg_codesign_dir/codesign-dmg.txt" <<'TXT'
Authority=Apple Distribution: Qiushan Huang (TEAMID)
TeamIdentifier=TEAMID
TXT
assert_fails_with \
  "DMG codesign evidence is missing Developer ID Application authority" \
  --artifact-dir "$invalid_dmg_codesign_dir" \
  --version "$version" \
  --suffix "$suffix" \
  --mode "$notarized_mode"

missing_dmg_team_dir="$(make_artifacts missing-dmg-team "$version" "$suffix" "$notarized_mode")"
write_notarized_evidence "$missing_dmg_team_dir"
cat >"$missing_dmg_team_dir/codesign-dmg.txt" <<'TXT'
Authority=Developer ID Application: Qiushan Huang (TEAMID)
TXT
assert_fails_with \
  "DMG codesign evidence is missing TeamIdentifier" \
  --artifact-dir "$missing_dmg_team_dir" \
  --version "$version" \
  --suffix "$suffix" \
  --mode "$notarized_mode"

assert_status 2 --unknown-option

echo "Release artifact verifier tests passed."
