#!/usr/bin/env bash
set -euo pipefail

APP_DISPLAY_NAME="MindDesk"

ARTIFACT_DIR=""
VERSION=""
RELEASE_PLATFORM_SUFFIX=""
MODE=""

usage() {
  cat <<USAGE
Usage: $0 --artifact-dir DIR --version VERSION --suffix SUFFIX --mode notarized|adhoc

Checks that a package_release.sh artifact directory contains the expected ZIP,
DMG, install notes, release notes, and a valid SHA256SUMS.txt.
USAGE
}

usage_error() {
  echo "$1" >&2
  usage >&2
  exit 2
}

fail() {
  echo "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-dir)
      [[ $# -ge 2 ]] || usage_error "Missing value for --artifact-dir"
      ARTIFACT_DIR="$2"
      shift 2
      ;;
    --version)
      [[ $# -ge 2 ]] || usage_error "Missing value for --version"
      VERSION="$2"
      shift 2
      ;;
    --suffix)
      [[ $# -ge 2 ]] || usage_error "Missing value for --suffix"
      RELEASE_PLATFORM_SUFFIX="$2"
      shift 2
      ;;
    --mode)
      [[ $# -ge 2 ]] || usage_error "Missing value for --mode"
      MODE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage_error "Unknown option: $1"
      ;;
  esac
done

[[ -n "$ARTIFACT_DIR" ]] || usage_error "Missing required option: --artifact-dir"
[[ -n "$VERSION" ]] || usage_error "Missing required option: --version"
[[ -n "$RELEASE_PLATFORM_SUFFIX" ]] || usage_error "Missing required option: --suffix"
[[ -n "$MODE" ]] || usage_error "Missing required option: --mode"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || usage_error "VERSION must be semantic x.y.z, got: ${VERSION:-<empty>}"
[[ "$RELEASE_PLATFORM_SUFFIX" =~ ^[A-Za-z0-9._-]+$ ]] || usage_error "suffix may contain only letters, numbers, dots, underscores, and hyphens."
case "$MODE" in
  notarized|adhoc) ;;
  *) usage_error "--mode must be notarized or adhoc, got: $MODE" ;;
esac

release_name="$APP_DISPLAY_NAME-v$VERSION-$RELEASE_PLATFORM_SUFFIX"
if [[ "$MODE" == "adhoc" ]]; then
  release_name="$release_name-adhoc"
fi

[[ -d "$ARTIFACT_DIR" ]] || fail "Missing artifact directory: $ARTIFACT_DIR"

require_nonempty_file() {
  local file="$1"
  if [[ ! -s "$file" ]]; then
    fail "Missing required artifact: $file"
  fi
}

require_nonempty_evidence_file() {
  local label="$1"
  local file="$2"
  if [[ ! -s "$file" ]]; then
    fail "Missing required $label: $file"
  fi
}

require_checksum_entry() {
  local filename="$1"
  if ! grep -Eq "^[[:xdigit:]]{64}[[:space:]]+[*]?${filename//./\\.}$" "$ARTIFACT_DIR/SHA256SUMS.txt"; then
    fail "SHA256SUMS.txt is missing checksum entry for: $filename"
  fi
}

json_field() {
  local file="$1"
  local field="$2"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" "$field" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], "r", encoding="utf-8") as handle:
        value = json.load(handle).get(sys.argv[2], "")
except Exception:
    value = ""
print(value)
PY
  else
    plutil -extract "$field" raw -o - "$file" 2>/dev/null || true
  fi
}

require_notarization_evidence() {
  local label="$1"
  local file="$ARTIFACT_DIR/notary-submit-$label.json"
  require_nonempty_evidence_file "notarization evidence" "$file"

  local status
  local submission_id
  status="$(json_field "$file" "status")"
  submission_id="$(json_field "$file" "id")"
  if [[ "$status" != "Accepted" || -z "$submission_id" ]]; then
    fail "Notarization was not accepted for $label: $file"
  fi
}

require_developer_id_codesign_evidence() {
  local evidence_label="$1"
  local failure_prefix="$2"
  local file="$3"

  require_nonempty_evidence_file "$evidence_label" "$file"
  if ! grep -Eq "^Authority=Developer ID Application:" "$file"; then
    fail "$failure_prefix is missing Developer ID Application authority: $file"
  fi
  if ! grep -Eq "^TeamIdentifier=[[:alnum:]]+$" "$file"; then
    fail "$failure_prefix is missing TeamIdentifier: $file"
  fi
}

require_codesign_evidence() {
  local codesign_log="$ARTIFACT_DIR/codesign-app.txt"
  local dmg_codesign_log="$ARTIFACT_DIR/codesign-dmg.txt"
  local entitlements_plist="$ARTIFACT_DIR/codesign-entitlements-app.plist"

  require_developer_id_codesign_evidence "codesign evidence" "Codesign evidence" "$codesign_log"
  require_developer_id_codesign_evidence "DMG codesign evidence" "DMG codesign evidence" "$dmg_codesign_log"
  require_nonempty_evidence_file "codesign evidence" "$entitlements_plist"
  if ! plutil -lint "$entitlements_plist" >/dev/null; then
    fail "Codesign entitlements evidence is not a valid plist: $entitlements_plist"
  fi
}

require_nonempty_file "$ARTIFACT_DIR/$release_name.zip"
require_nonempty_file "$ARTIFACT_DIR/$release_name.dmg"
require_nonempty_file "$ARTIFACT_DIR/INSTALL.txt"
require_nonempty_file "$ARTIFACT_DIR/RELEASE-NOTES.md"
require_nonempty_file "$ARTIFACT_DIR/SHA256SUMS.txt"

require_checksum_entry "$release_name.zip"
require_checksum_entry "$release_name.dmg"

checksum_output=""
if ! checksum_output="$(cd "$ARTIFACT_DIR" && shasum -a 256 -c "SHA256SUMS.txt" 2>&1)"; then
  echo "Checksum verification failed: $ARTIFACT_DIR/SHA256SUMS.txt" >&2
  printf '%s\n' "$checksum_output" >&2
  exit 1
fi

if [[ "$MODE" == "notarized" ]]; then
  require_notarization_evidence "app"
  require_notarization_evidence "dmg"
  require_codesign_evidence
fi

echo "Release artifacts ok: $ARTIFACT_DIR"
