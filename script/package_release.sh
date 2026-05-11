#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MindDesk"
APP_DISPLAY_NAME="MindDesk"
BUNDLE_ID="studio.qiushan.minddesk"
MIN_SYSTEM_VERSION="14.0"
COPYRIGHT="Copyright © 2026 Qiushan Huang. All rights reserved."
RELEASE_PLATFORM_SUFFIX="${RELEASE_PLATFORM_SUFFIX:-macOS}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' <"$ROOT_DIR/VERSION")"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must be semantic x.y.z, got: ${VERSION:-<empty>}" >&2
  exit 1
fi
if [[ ! "$RELEASE_PLATFORM_SUFFIX" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "RELEASE_PLATFORM_SUFFIX may contain only letters, numbers, dots, underscores, and hyphens." >&2
  exit 1
fi

MODE="${RELEASE_MODE:-notarized}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
TEAM_ID="${TEAM_ID:-}"
NOTARY_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-minddesk-notary}"
NOTARY_KEY="${NOTARY_KEY:-}"
NOTARY_KEY_ID="${NOTARY_KEY_ID:-}"
NOTARY_ISSUER="${NOTARY_ISSUER:-}"
NOTARY_TIMEOUT="${NOTARY_TIMEOUT:-30m}"
ENTITLEMENTS_FILE="$ROOT_DIR/script/release.entitlements"
RELEASE_NOTES_SOURCE="$ROOT_DIR/docs/releases/v$VERSION.md"
ALLOW_ADHOC_RELEASE="${ALLOW_ADHOC_RELEASE:-0}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Options:
  --mode notarized|adhoc          Default: notarized
  --identity IDENTITY             Developer ID Application identity for notarized releases
  --team-id TEAMID                Apple Developer Team ID; must match the Developer ID identity
  --notary-profile PROFILE        notarytool keychain profile, default: minddesk-notary
  --notary-key PATH               App Store Connect API key path alternative to keychain profile
  --notary-key-id KEY_ID          API key id for --notary-key
  --notary-issuer ISSUER_ID       API issuer id for --notary-key
  --notary-timeout DURATION       notarytool --wait timeout, default: 30m
  --entitlements PATH             Entitlements plist, default: script/release.entitlements
  --allow-adhoc                   Required with --mode adhoc
  -h, --help                      Show this help

Environment fallbacks:
  RELEASE_MODE, CODESIGN_IDENTITY, TEAM_ID, NOTARY_KEYCHAIN_PROFILE,
  NOTARY_KEY, NOTARY_KEY_ID, NOTARY_ISSUER, NOTARY_TIMEOUT,
  RELEASE_PLATFORM_SUFFIX, ALLOW_ADHOC_RELEASE=1
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:?Missing value for --mode}"
      shift 2
      ;;
    --identity)
      CODESIGN_IDENTITY="${2:?Missing value for --identity}"
      shift 2
      ;;
    --team-id)
      TEAM_ID="${2:?Missing value for --team-id}"
      shift 2
      ;;
    --notary-profile)
      NOTARY_PROFILE="${2:?Missing value for --notary-profile}"
      shift 2
      ;;
    --notary-key)
      NOTARY_KEY="${2:?Missing value for --notary-key}"
      shift 2
      ;;
    --notary-key-id)
      NOTARY_KEY_ID="${2:?Missing value for --notary-key-id}"
      shift 2
      ;;
    --notary-issuer)
      NOTARY_ISSUER="${2:?Missing value for --notary-issuer}"
      shift 2
      ;;
    --notary-timeout)
      NOTARY_TIMEOUT="${2:?Missing value for --notary-timeout}"
      shift 2
      ;;
    --entitlements)
      ENTITLEMENTS_FILE="${2:?Missing value for --entitlements}"
      shift 2
      ;;
    --allow-adhoc)
      ALLOW_ADHOC_RELEASE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "$MODE" in
  notarized|adhoc) ;;
  *)
    echo "--mode must be notarized or adhoc, got: $MODE" >&2
    exit 1
    ;;
esac

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1" >&2
    exit 1
  fi
}

require_xcrun_tool() {
  if ! xcrun --find "$1" >/dev/null 2>&1; then
    echo "Missing required Xcode tool: $1" >&2
    exit 1
  fi
}

developer_id_identity_record() {
  security find-identity -p codesigning -v 2>/dev/null | grep -F "$CODESIGN_IDENTITY" | head -n 1 || true
}

validate_release_notes() {
  if [[ ! -s "$RELEASE_NOTES_SOURCE" ]]; then
    echo "Notarized release requires non-empty release notes: $RELEASE_NOTES_SOURCE" >&2
    exit 1
  fi
  if ! grep -qx "# $APP_DISPLAY_NAME v$VERSION" "$RELEASE_NOTES_SOURCE"; then
    echo "Release notes must include heading: # $APP_DISPLAY_NAME v$VERSION" >&2
    exit 1
  fi
  if ! grep -qx "## Distribution" "$RELEASE_NOTES_SOURCE"; then
    echo "Release notes must include a Distribution section." >&2
    exit 1
  fi
  if ! grep -qx "## Validation" "$RELEASE_NOTES_SOURCE"; then
    echo "Release notes must include a Validation section." >&2
    exit 1
  fi
}

validate_notarized_release_inputs() {
  require_tool security
  require_xcrun_tool notarytool
  require_xcrun_tool stapler

  if [[ -z "$CODESIGN_IDENTITY" ]]; then
    echo "Notarized release requires --identity or CODESIGN_IDENTITY." >&2
    echo "Expected a Developer ID Application identity, for example:" >&2
    echo "  --identity \"Developer ID Application: Qiushan Huang (TEAMID)\"" >&2
    exit 1
  fi
  if [[ -z "$TEAM_ID" ]]; then
    echo "Notarized release requires --team-id or TEAM_ID." >&2
    exit 1
  fi
  if [[ ! -f "$ENTITLEMENTS_FILE" ]]; then
    echo "Missing entitlements file: $ENTITLEMENTS_FILE" >&2
    exit 1
  fi

  local identity_record
  identity_record="$(developer_id_identity_record)"
  if [[ "$CODESIGN_IDENTITY" != Developer\ ID\ Application:* && "$identity_record" != *"Developer ID Application"* ]]; then
    echo "Notarized release identity must be a Developer ID Application certificate." >&2
    echo "Found: ${CODESIGN_IDENTITY:-<empty>}" >&2
    exit 1
  fi
  if [[ "$CODESIGN_IDENTITY" != *"($TEAM_ID)"* && "$identity_record" != *"($TEAM_ID)"* ]]; then
    echo "TEAM_ID does not match the signing identity." >&2
    echo "TEAM_ID: $TEAM_ID" >&2
    echo "Identity: $CODESIGN_IDENTITY" >&2
    exit 1
  fi

  local api_key_parts=0
  [[ -n "$NOTARY_KEY" ]] && api_key_parts=$((api_key_parts + 1))
  [[ -n "$NOTARY_KEY_ID" ]] && api_key_parts=$((api_key_parts + 1))
  [[ -n "$NOTARY_ISSUER" ]] && api_key_parts=$((api_key_parts + 1))

  if [[ "$api_key_parts" -gt 0 && "$api_key_parts" -lt 3 ]]; then
    echo "API key notarization requires all three options: --notary-key, --notary-key-id, and --notary-issuer." >&2
    exit 1
  fi

  if [[ "$api_key_parts" -eq 3 ]]; then
    if [[ ! -r "$NOTARY_KEY" ]]; then
      echo "Notary API key is not readable: $NOTARY_KEY" >&2
      exit 1
    fi
    NOTARY_ARGS=(--key "$NOTARY_KEY" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER")
  elif [[ -n "$NOTARY_PROFILE" ]]; then
    NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
  else
    echo "Notarized release requires notary credentials." >&2
    echo "Preferred setup:" >&2
    echo "  xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <email> --team-id $TEAM_ID" >&2
    echo "Then rerun with --notary-profile $NOTARY_PROFILE." >&2
    echo "API key alternative: --notary-key PATH --notary-key-id ID --notary-issuer ISSUER" >&2
    exit 1
  fi

  local preflight_error
  preflight_error="$(mktemp)"
  if ! xcrun notarytool history "${NOTARY_ARGS[@]}" --output-format json >/dev/null 2>"$preflight_error"; then
    echo "Notary credentials could not be verified before building." >&2
    cat "$preflight_error" >&2
    rm -f "$preflight_error"
    exit 1
  fi
  rm -f "$preflight_error"
}

validate_adhoc_release_inputs() {
  if [[ "$ALLOW_ADHOC_RELEASE" != "1" ]]; then
    echo "Ad-hoc packages are internal only. Re-run with --mode adhoc --allow-adhoc to opt in." >&2
    exit 1
  fi
}

if [[ "$MODE" == "notarized" ]]; then
  declare -a NOTARY_ARGS
  validate_release_notes
  validate_notarized_release_inputs
else
  validate_adhoc_release_inputs
fi

IFS=. read -r VERSION_MAJOR VERSION_MINOR VERSION_PATCH <<<"$VERSION"
BUILD_NUMBER="${BUILD_NUMBER:-$((VERSION_MAJOR * 10000 + VERSION_MINOR * 100 + VERSION_PATCH))}"
RELEASE_NAME="$APP_DISPLAY_NAME-v$VERSION-$RELEASE_PLATFORM_SUFFIX"
if [[ "$MODE" == "adhoc" ]]; then
  RELEASE_NAME="$RELEASE_NAME-adhoc"
fi
RELEASE_DIR="$ROOT_DIR/dist/release/$RELEASE_NAME"
PAYLOAD_DIR="$RELEASE_DIR/payload"
DMG_ROOT="$RELEASE_DIR/dmg-root"
ARTIFACT_DIR="$RELEASE_DIR/artifacts"
APP_BUNDLE="$PAYLOAD_DIR/$APP_DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
SOURCE_RESOURCES="$ROOT_DIR/Sources/MindDesk/Resources"
ZIP_PATH="$ARTIFACT_DIR/$RELEASE_NAME.zip"
DMG_PATH="$ARTIFACT_DIR/$RELEASE_NAME.dmg"

if [[ -e "$RELEASE_DIR" ]]; then
  echo "Release directory already exists: $RELEASE_DIR" >&2
  echo "Move it aside or choose a new VERSION before packaging." >&2
  exit 1
fi

extract_json_field() {
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

submit_for_notarization() {
  local artifact="$1"
  local label="$2"
  local submit_json="$ARTIFACT_DIR/notary-submit-$label.json"
  local log_json="$ARTIFACT_DIR/notary-log-$label.json"
  local submit_error="$ARTIFACT_DIR/notary-submit-$label.stderr"

  echo "Submitting $label for notarization..."
  local submit_exit
  set +e
  xcrun notarytool submit "$artifact" "${NOTARY_ARGS[@]}" \
    --wait \
    --timeout "$NOTARY_TIMEOUT" \
    --output-format json >"$submit_json" 2>"$submit_error"
  submit_exit=$?
  set -e

  local status
  status="$(extract_json_field "$submit_json" "status")"
  local submission_id
  submission_id="$(extract_json_field "$submit_json" "id")"
  if [[ -n "$submission_id" ]]; then
    xcrun notarytool log "$submission_id" "${NOTARY_ARGS[@]}" \
      --output-format json >"$log_json" || true
  fi
  if [[ "$submit_exit" -ne 0 || "$status" != "Accepted" ]]; then
    echo "Notarization failed for $label. See: $submit_json $log_json" >&2
    if [[ -s "$submit_error" ]]; then
      cat "$submit_error" >&2
    fi
    exit 1
  fi
}

cd "$ROOT_DIR"
swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"
RESOURCE_BUNDLE="$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle"

mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$ARTIFACT_DIR" "$DMG_ROOT"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$SOURCE_RESOURCES/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
  echo "Missing SwiftPM resource bundle: $RESOURCE_BUNDLE" >&2
  exit 1
fi
cp -R "$RESOURCE_BUNDLE" "$APP_RESOURCES/"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSHumanReadableCopyright</key>
  <string>$COPYRIGHT</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>MindDesk uses Automation only after confirmation to create Finder aliases and run commands in Terminal.</string>
  <key>NSDesktopFolderUsageDescription</key>
  <string>MindDesk can create Finder aliases in folders you choose.</string>
  <key>NSDocumentsFolderUsageDescription</key>
  <string>MindDesk can create Finder aliases in folders you choose.</string>
</dict>
</plist>
PLIST

if [[ "$MODE" == "notarized" ]]; then
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS_FILE" \
    --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE"
  SIGNING_STATUS="Signed with Developer ID identity and notarized: $CODESIGN_IDENTITY"

  codesign --verify --deep --strict "$APP_BUNDLE"
  codesign -dvvv --entitlements :- "$APP_BUNDLE" >"$ARTIFACT_DIR/codesign-entitlements-app.plist" 2>"$ARTIFACT_DIR/codesign-app.txt" || {
    cat "$ARTIFACT_DIR/codesign-app.txt" >&2
    exit 1
  }

  APP_NOTARY_ZIP="$ARTIFACT_DIR/$RELEASE_NAME-notary-upload-app.zip"
  ditto -c -k --keepParent "$APP_BUNDLE" "$APP_NOTARY_ZIP"
  submit_for_notarization "$APP_NOTARY_ZIP" "app"
  xcrun stapler staple "$APP_BUNDLE"
  xcrun stapler validate "$APP_BUNDLE"
  spctl --assess --type execute --verbose=4 "$APP_BUNDLE"
  rm -f "$APP_NOTARY_ZIP"
else
  codesign --force --sign - "$APP_BUNDLE"
  SIGNING_STATUS="Ad-hoc signed internal package. This build is not notarized."
  codesign --verify --deep --strict "$APP_BUNDLE"
fi

ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

cp -R "$APP_BUNDLE" "$DMG_ROOT/$APP_DISPLAY_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create \
  -volname "$APP_DISPLAY_NAME $VERSION" \
  -srcfolder "$DMG_ROOT" \
  -format UDZO \
  "$DMG_PATH" >/dev/null

if [[ "$MODE" == "notarized" ]]; then
  codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$DMG_PATH"
  codesign --verify --strict "$DMG_PATH"
  submit_for_notarization "$DMG_PATH" "dmg"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"
fi

if [[ "$MODE" == "notarized" ]]; then
  INSTALL_SECURITY_TEXT="This release is Developer ID signed, notarized, and stapled."
else
  INSTALL_SECURITY_TEXT="This is an internal ad-hoc package. It is not notarized and may be blocked by Gatekeeper."
fi

cat >"$ARTIFACT_DIR/INSTALL.txt" <<TXT
$APP_DISPLAY_NAME $VERSION

Install:
1. Open $RELEASE_NAME.dmg.
2. Drag $APP_DISPLAY_NAME.app to Applications.
3. Launch $APP_DISPLAY_NAME from Applications.

$SIGNING_STATUS
$INSTALL_SECURITY_TEXT
TXT

if [[ -f "$RELEASE_NOTES_SOURCE" ]]; then
  cp "$RELEASE_NOTES_SOURCE" "$ARTIFACT_DIR/RELEASE-NOTES.md"
else
  cat >"$ARTIFACT_DIR/RELEASE-NOTES.md" <<TXT
# $APP_DISPLAY_NAME $VERSION

macOS release package for MindDesk.

## Current Features

- Native macOS workbench for folders, files, snippets, and visual workflow maps.
- Workspace canvas with resource cards, notes, organization frames, arrow links, and animated flow lines.
- Global and pinned resource libraries with Finder open/reveal and path copy actions.
- SwiftData local storage with JSON import/export support.

## Distribution

- macOS $MIN_SYSTEM_VERSION or newer.
- $SIGNING_STATUS
- License: MIT.
- $COPYRIGHT
TXT
fi

(
  cd "$ARTIFACT_DIR"
  shasum -a 256 "$RELEASE_NAME.zip" "$RELEASE_NAME.dmg" >"SHA256SUMS.txt"
)

/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST" >/dev/null

echo "Release artifacts:"
echo "$ZIP_PATH"
echo "$DMG_PATH"
echo "$ARTIFACT_DIR/SHA256SUMS.txt"
if [[ "$MODE" == "notarized" ]]; then
  echo "$ARTIFACT_DIR/notary-submit-app.json"
  echo "$ARTIFACT_DIR/notary-submit-dmg.json"
fi
