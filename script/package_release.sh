#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MindDesk"
APP_DISPLAY_NAME="MindDesk"
BUNDLE_ID="studio.qiushan.minddesk"
MIN_SYSTEM_VERSION="14.0"
COPYRIGHT="Copyright © 2026 Qiushan Huang. All rights reserved."
ROOT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKTREE_GUARD="$ROOT_DIR/script/verify_release_worktree.sh"
S0_VERIFIER="$ROOT_DIR/script/verify_s0_private_canvas.sh"
ARTIFACT_VERIFIER="$ROOT_DIR/script/verify_release_artifacts.sh"
FAILURE_ARTIFACT_PRESERVER="$ROOT_DIR/script/preserve_release_failure_artifacts.sh"
VERSION="$(tr -d '[:space:]' <"$ROOT_DIR/VERSION")"
SUFFIX="${RELEASE_PLATFORM_SUFFIX:-macOS}"
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
  cat <<'USAGE'
Usage: package_release.sh [options]
  --mode notarized|adhoc
  --identity IDENTITY
  --team-id TEAMID
  --notary-profile PROFILE
  --notary-key PATH --notary-key-id ID --notary-issuer ISSUER
  --notary-timeout DURATION
  --entitlements PATH
  --allow-adhoc
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:?missing --mode value}"; shift 2 ;;
    --identity) CODESIGN_IDENTITY="${2:?missing --identity value}"; shift 2 ;;
    --team-id) TEAM_ID="${2:?missing --team-id value}"; shift 2 ;;
    --notary-profile) NOTARY_PROFILE="${2:?missing --notary-profile value}"; shift 2 ;;
    --notary-key) NOTARY_KEY="${2:?missing --notary-key value}"; shift 2 ;;
    --notary-key-id) NOTARY_KEY_ID="${2:?missing --notary-key-id value}"; shift 2 ;;
    --notary-issuer) NOTARY_ISSUER="${2:?missing --notary-issuer value}"; shift 2 ;;
    --notary-timeout) NOTARY_TIMEOUT="${2:?missing --notary-timeout value}"; shift 2 ;;
    --entitlements) ENTITLEMENTS_FILE="${2:?missing --entitlements value}"; shift 2 ;;
    --allow-adhoc) ALLOW_ADHOC_RELEASE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "VERSION must be semantic x.y.z" >&2; exit 1; }
[[ "$SUFFIX" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "RELEASE_PLATFORM_SUFFIX may contain only letters, numbers, dots, underscores, and hyphens." >&2; exit 1; }
[[ "$MODE" == "adhoc" || "$MODE" == "notarized" ]] || { echo "--mode must be notarized or adhoc" >&2; exit 1; }

require_tool() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required tool: $1" >&2; exit 1; }; }
sha256() { shasum -a 256 "$1" | awk '{print $1}'; }

for tool in git swift swiftc python3 shasum awk find cmp codesign ditto hdiutil plutil; do require_tool "$tool"; done
[[ -x "$WORKTREE_GUARD" && -x "$S0_VERIFIER" && -x "$ARTIFACT_VERIFIER" ]] || { echo "Missing executable release verifier" >&2; exit 1; }

if [[ "$MODE" == "adhoc" ]]; then
  [[ "$ALLOW_ADHOC_RELEASE" == "1" ]] || { echo "Ad-hoc packages are internal only. Re-run with --mode adhoc --allow-adhoc to opt in." >&2; exit 1; }
else
  require_tool security
  require_tool xcrun
  require_tool spctl
  [[ -n "$CODESIGN_IDENTITY" ]] || { echo "Notarized release requires --identity or CODESIGN_IDENTITY." >&2; exit 1; }
  [[ -n "$TEAM_ID" ]] || { echo "Notarized release requires --team-id or TEAM_ID." >&2; exit 1; }
  [[ -f "$ENTITLEMENTS_FILE" && ! -L "$ENTITLEMENTS_FILE" ]] || { echo "Missing entitlements file: $ENTITLEMENTS_FILE" >&2; exit 1; }
  [[ -s "$RELEASE_NOTES_SOURCE" ]] || { echo "Notarized release requires release notes: $RELEASE_NOTES_SOURCE" >&2; exit 1; }
  api_parts=0
  [[ -n "$NOTARY_KEY" ]] && api_parts=$((api_parts + 1))
  [[ -n "$NOTARY_KEY_ID" ]] && api_parts=$((api_parts + 1))
  [[ -n "$NOTARY_ISSUER" ]] && api_parts=$((api_parts + 1))
  [[ "$api_parts" -eq 0 || "$api_parts" -eq 3 ]] || { echo "API key notarization requires all three options" >&2; exit 1; }
  if [[ "$api_parts" -eq 3 ]]; then
    [[ -r "$NOTARY_KEY" ]] || { echo "Notary API key is not readable: $NOTARY_KEY" >&2; exit 1; }
    NOTARY_ARGS=(--key "$NOTARY_KEY" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER")
  else
    [[ -n "$NOTARY_PROFILE" ]] || { echo "Notarized release requires notary credentials" >&2; exit 1; }
    NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
  fi
fi

cd "$ROOT_DIR"
"$WORKTREE_GUARD" --root "$ROOT_DIR"
[[ -z "$(git status --short)" ]] || { echo "Release requires a completely clean worktree" >&2; exit 1; }
SOURCE_HEAD="$(git rev-parse HEAD)"
[[ "$SOURCE_HEAD" =~ ^[0-9a-f]{40,64}$ ]] || { echo "Could not capture full source HEAD" >&2; exit 1; }

# This gate must remain before the first SwiftPM invocation.
"$S0_VERIFIER" --repo-root "$ROOT_DIR" --package-manifest-only

BUILD_SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/minddesk-release-build.XXXXXX")"
BUILD_EVIDENCE="$(mktemp -d "${TMPDIR:-/tmp}/minddesk-release-evidence.XXXXXX")"
chmod 0700 "$BUILD_SCRATCH" "$BUILD_EVIDENCE"
BUILD_SCRATCH="$(cd -P "$BUILD_SCRATCH" && pwd)"
BUILD_EVIDENCE="$(cd -P "$BUILD_EVIDENCE" && pwd)"

IFS=. read -r VERSION_MAJOR VERSION_MINOR VERSION_PATCH <<<"$VERSION"
BUILD_NUMBER="${BUILD_NUMBER:-$((10#$VERSION_MAJOR * 10000 + 10#$VERSION_MINOR * 100 + 10#$VERSION_PATCH))}"
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo "BUILD_NUMBER must be a positive integer" >&2; exit 1; }
RELEASE_NAME="$APP_DISPLAY_NAME-v$VERSION-$SUFFIX"
[[ "$MODE" == "adhoc" ]] && RELEASE_NAME="$RELEASE_NAME-adhoc"
RELEASE_ROOT="$ROOT_DIR/dist/release"
FINAL_RELEASE_DIR="$RELEASE_ROOT/$RELEASE_NAME"
STAGING_DIR="$RELEASE_ROOT/.staging-$RELEASE_NAME-$$"
PAYLOAD_DIR="$STAGING_DIR/payload"
DMG_ROOT="$STAGING_DIR/dmg-root"
ARTIFACT_DIR="$STAGING_DIR/artifacts"
APP_BUNDLE="$PAYLOAD_DIR/$APP_DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_BINARY="$APP_CONTENTS/MacOS/$APP_NAME"
ZIP_PATH="$ARTIFACT_DIR/$RELEASE_NAME.zip"
DMG_PATH="$ARTIFACT_DIR/$RELEASE_NAME.dmg"
DMG_MOUNT=""

[[ ! -e "$FINAL_RELEASE_DIR" && ! -L "$FINAL_RELEASE_DIR" ]] || { echo "Release directory already exists: $FINAL_RELEASE_DIR" >&2; exit 1; }
[[ ! -e "$STAGING_DIR" && ! -L "$STAGING_DIR" ]] || { echo "Staging directory already exists: $STAGING_DIR" >&2; exit 1; }

cleanup() {
  status=$?
  set +e
  if [[ -n "$DMG_MOUNT" && -d "$DMG_MOUNT" ]]; then hdiutil detach "$DMG_MOUNT" -force >/dev/null 2>&1 || true; fi
  if [[ "$status" -ne 0 && -d "$ARTIFACT_DIR" && -x "$FAILURE_ARTIFACT_PRESERVER" ]]; then
    bash "$FAILURE_ARTIFACT_PRESERVER" --artifact-dir "$ARTIFACT_DIR" --release-root "$RELEASE_ROOT" --release-name "$RELEASE_NAME" >&2 || true
  fi
  [[ -d "$STAGING_DIR" && ! -L "$STAGING_DIR" ]] && rm -rf -- "$STAGING_DIR"
  [[ -d "$BUILD_SCRATCH" && ! -L "$BUILD_SCRATCH" ]] && rm -rf -- "$BUILD_SCRATCH"
  [[ -d "$BUILD_EVIDENCE" && ! -L "$BUILD_EVIDENCE" ]] && rm -rf -- "$BUILD_EVIDENCE"
  return "$status"
}
trap cleanup EXIT

bundle_manifest() {
  local bundle="$1"
  local output="$2"
  python3 - "$bundle" "$output" <<'PY'
import hashlib, json, os, stat, sys
root, output = map(os.path.abspath, sys.argv[1:])
if not os.path.isdir(root) or os.path.islink(root): raise SystemExit("unsafe bundle root")
entries=[]
for directory, dirnames, filenames in os.walk(root, topdown=True, followlinks=False):
    dirnames.sort(key=lambda value: value.encode("utf-8")); filenames.sort(key=lambda value: value.encode("utf-8"))
    for name in dirnames:
        path=os.path.join(directory,name); info=os.lstat(path)
        if not stat.S_ISDIR(info.st_mode) or os.path.islink(path): raise SystemExit("symlink or non-directory in app bundle")
        relative=os.path.relpath(path,root).replace(os.sep,"/")
        entries.append({"relativePath":relative,"type":"directory","mode":format(stat.S_IMODE(info.st_mode),"04o")})
    for name in filenames:
        path=os.path.join(directory,name); info=os.lstat(path)
        if not stat.S_ISREG(info.st_mode) or os.path.islink(path): raise SystemExit("symlink or non-file in app bundle")
        relative=os.path.relpath(path,root).replace(os.sep,"/")
        digest=hashlib.sha256(open(path,"rb").read()).hexdigest()
        entries.append({"relativePath":relative,"type":"file","mode":format(stat.S_IMODE(info.st_mode),"04o"),"size":info.st_size,"sha256":digest})
entries.sort(key=lambda item:item["relativePath"].encode("utf-8"))
with open(output,"w",encoding="utf-8",newline="\n") as handle:
    json.dump({"schemaVersion":1,"entries":entries},handle,sort_keys=True,separators=(",",":")); handle.write("\n")
PY
}

compare_bundle_manifest() {
  local bundle="$1" expected="$2" candidate
  candidate="$(mktemp "${TMPDIR:-/tmp}/minddesk-bundle-manifest.XXXXXX")"
  bundle_manifest "$bundle" "$candidate"
  cmp -s "$candidate" "$expected" || { rm -f "$candidate"; echo "Bundle manifest mismatch: $bundle" >&2; exit 1; }
  rm -f "$candidate"
}

verify_bundle_policy() {
  local bundle="$1"
  "$S0_VERIFIER" --repo-root "$ROOT_DIR" --scratch-path "$BUILD_SCRATCH" --configuration release \
    --build-description "$BUILD_DESCRIPTION" --evidence-dir "$BUILD_EVIDENCE" \
    --binary "$bundle/Contents/MacOS/$APP_NAME" --app-bundle "$bundle"
}

verify_final_policy() {
  # Signing legitimately changes the Mach-O signature bytes. Revalidate the
  # frozen build input and bind every signed copy through the final manifest.
  "$S0_VERIFIER" --repo-root "$ROOT_DIR" --scratch-path "$BUILD_SCRATCH" --configuration release \
    --build-description "$BUILD_DESCRIPTION" --evidence-dir "$BUILD_EVIDENCE" --binary "$BUILD_BINARY"
}

strict_notary_status() {
  python3 - "$1" <<'PY'
import json,sys
def pairs(items):
    value={}
    for key,item in items:
        if key in value: raise SystemExit("duplicate key in notary JSON")
        value[key]=item
    return value
document=json.load(open(sys.argv[1],encoding="utf-8"),object_pairs_hook=pairs)
if not isinstance(document,dict) or not isinstance(document.get("id"),str) or not document["id"] or document.get("status") != "Accepted":
    raise SystemExit("notary JSON is not an accepted object")
PY
}

submit_notary() {
  local target="$1" label="$2" output="$ARTIFACT_DIR/notary-submit-$label.json" stderr="$ARTIFACT_DIR/notary-submit-$label.stderr"
  if ! xcrun notarytool submit "$target" "${NOTARY_ARGS[@]}" --wait --timeout "$NOTARY_TIMEOUT" --output-format json >"$output" 2>"$stderr"; then
    echo "Notarization failed for $label" >&2; cat "$stderr" >&2; exit 1
  fi
  strict_notary_status "$output"
}

mkdir -p "$APP_CONTENTS/MacOS" "$APP_CONTENTS/Resources" "$ARTIFACT_DIR" "$DMG_ROOT"

swift build --package-path "$ROOT_DIR" --scratch-path "$BUILD_SCRATCH" -c release
BUILD_DIR="$(swift build --package-path "$ROOT_DIR" --scratch-path "$BUILD_SCRATCH" -c release --show-bin-path)"
BUILD_DIR="$(cd -P "$BUILD_DIR" && pwd)"
[[ "$BUILD_DIR" == "$BUILD_SCRATCH"/* && -d "$BUILD_DIR" && ! -L "$BUILD_DIR" ]] || { echo "SwiftPM returned a build directory outside the private scratch" >&2; exit 1; }
BUILD_BINARY="$BUILD_DIR/$APP_NAME"
[[ -f "$BUILD_BINARY" && ! -L "$BUILD_BINARY" ]] || { echo "Release build did not produce MindDesk" >&2; exit 1; }
descriptions=()
while IFS= read -r -d '' description; do descriptions+=("$description"); done < <(find -P "$BUILD_SCRATCH" -type f -path '*/release/description.json' -print0)
[[ "${#descriptions[@]}" -eq 1 ]] || { echo "Expected exactly one Release description.json" >&2; exit 1; }
BUILD_DESCRIPTION="${descriptions[0]}"
BUILD_DESCRIPTION_SHA="$(sha256 "$BUILD_DESCRIPTION")"

"$S0_VERIFIER" --repo-root "$ROOT_DIR" --scratch-path "$BUILD_SCRATCH" --configuration release \
  --build-description "$BUILD_DESCRIPTION" --evidence-dir "$BUILD_EVIDENCE" --binary "$BUILD_BINARY"
SCRATCH_BINARY_SHA="$(sha256 "$BUILD_BINARY")"

cp "$BUILD_BINARY" "$APP_BINARY"
chmod 0755 "$APP_BINARY"
cp "$ROOT_DIR/Sources/MindDesk/Resources/AppIcon.icns" "$APP_CONTENTS/Resources/AppIcon.icns"
shopt -s nullglob
resource_bundles=("$BUILD_DIR"/*.bundle)
shopt -u nullglob
[[ "${#resource_bundles[@]}" -ge 1 ]] || { echo "Missing SwiftPM resource bundle" >&2; exit 1; }
for resource_bundle in "${resource_bundles[@]}"; do cp -R "$resource_bundle" "$APP_CONTENTS/Resources/"; done

cat >"$APP_CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>$APP_DISPLAY_NAME</string>
<key>CFBundleDisplayName</key><string>$APP_DISPLAY_NAME</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
<key>LSMinimumSystemVersion</key><string>$MIN_SYSTEM_VERSION</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHumanReadableCopyright</key><string>$COPYRIGHT</string>
<key>NSDesktopFolderUsageDescription</key><string>MindDesk can open local files and folders you choose.</string>
<key>NSDocumentsFolderUsageDescription</key><string>MindDesk can open local files and folders you choose.</string>
</dict></plist>
PLIST
plutil -lint "$APP_CONTENTS/Info.plist" >/dev/null
[[ "$(sha256 "$APP_BINARY")" == "$SCRATCH_BINARY_SHA" ]] || { echo "Unsigned app binary differs from fresh Release output" >&2; exit 1; }

verify_bundle_policy "$APP_BUNDLE"
PRE_SIGN_MANIFEST="$ARTIFACT_DIR/pre-sign.bundle.manifest.json"
bundle_manifest "$APP_BUNDLE" "$PRE_SIGN_MANIFEST"
compare_bundle_manifest "$APP_BUNDLE" "$PRE_SIGN_MANIFEST"

NORMALIZED_PLAN="$BUILD_EVIDENCE/normalized-build-plan.json"
SOURCE_POLICY="$BUILD_EVIDENCE/source-policy-evidence.json"
python3 - "$ARTIFACT_DIR/build-provenance.json" "$SOURCE_HEAD" "$BUILD_DESCRIPTION_SHA" \
  "$(sha256 "$NORMALIZED_PLAN")" "$(sha256 "$SOURCE_POLICY")" "$SCRATCH_BINARY_SHA" \
  "$(sha256 "$APP_BINARY")" "$(sha256 "$PRE_SIGN_MANIFEST")" <<'PY'
import json,sys
output,head,description,plan,policy,scratch,unsigned,manifest=sys.argv[1:]
value={"schemaVersion":1,"sourceHead":head,"configuration":"release","buildDescriptionSha256":description,
"normalizedBuildPlanSha256":plan,"sourcePolicyEvidenceSha256":policy,"scratchBinarySha256":scratch,
"unsignedBundleBinarySha256":unsigned,"preSignBundleManifestSha256":manifest}
with open(output,"w",encoding="utf-8",newline="\n") as handle: json.dump(value,handle,sort_keys=True,separators=(",",":")); handle.write("\n")
PY

compare_bundle_manifest "$APP_BUNDLE" "$PRE_SIGN_MANIFEST"
if [[ "$MODE" == "notarized" ]]; then
  codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS_FILE" --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE"
  codesign --verify --deep --strict "$APP_BUNDLE"
  codesign -dvvv --entitlements :- "$APP_BUNDLE" >"$ARTIFACT_DIR/codesign-entitlements-app.plist" 2>"$ARTIFACT_DIR/codesign-app.txt"
  APP_NOTARY_ZIP="$STAGING_DIR/$RELEASE_NAME-notary-upload.zip"
  COPYFILE_DISABLE=1 ditto -c -k --keepParent "$APP_BUNDLE" "$APP_NOTARY_ZIP"
  submit_notary "$APP_NOTARY_ZIP" app
  xcrun stapler staple "$APP_BUNDLE"
  xcrun stapler validate "$APP_BUNDLE"
  spctl --assess --type execute --verbose=4 "$APP_BUNDLE"
  rm -f "$APP_NOTARY_ZIP"
else
  codesign --force --sign - "$APP_BUNDLE"
  codesign --verify --deep --strict "$APP_BUNDLE"
fi

verify_final_policy
FINAL_MANIFEST="$ARTIFACT_DIR/final-app.bundle.manifest.json"
bundle_manifest "$APP_BUNDLE" "$FINAL_MANIFEST"
compare_bundle_manifest "$APP_BUNDLE" "$FINAL_MANIFEST"

COPYFILE_DISABLE=1 ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
ZIP_SHA="$(sha256 "$ZIP_PATH")"
python3 - "$ZIP_PATH" <<'PY'
import stat,sys,zipfile
seen=set()
with zipfile.ZipFile(sys.argv[1]) as archive:
    for item in archive.infolist():
        name=item.filename
        if name in seen or name.startswith("/") or "\\" in name or any(part in ("", ".", "..") for part in name.rstrip("/").split("/")):
            raise SystemExit("unsafe or duplicate ZIP entry")
        seen.add(name)
        if name.rstrip("/").split("/",1)[0] != "MindDesk.app": raise SystemExit("ZIP contains an extra root")
        mode=(item.external_attr >> 16)
        if stat.S_ISLNK(mode): raise SystemExit("ZIP contains a symlink")
PY
ZIP_EXTRACT="$(mktemp -d "${TMPDIR:-/tmp}/minddesk-release-zip.XXXXXX")"
ditto -x -k "$ZIP_PATH" "$ZIP_EXTRACT"
[[ -d "$ZIP_EXTRACT/$APP_DISPLAY_NAME.app" && ! -L "$ZIP_EXTRACT/$APP_DISPLAY_NAME.app" ]] || { echo "ZIP did not extract one real app" >&2; exit 1; }
compare_bundle_manifest "$ZIP_EXTRACT/$APP_DISPLAY_NAME.app" "$FINAL_MANIFEST"
codesign --verify --deep --strict "$ZIP_EXTRACT/$APP_DISPLAY_NAME.app"
[[ "$MODE" == "adhoc" ]] || { xcrun stapler validate "$ZIP_EXTRACT/$APP_DISPLAY_NAME.app"; spctl --assess --type execute --verbose=4 "$ZIP_EXTRACT/$APP_DISPLAY_NAME.app"; }
verify_final_policy
rm -rf -- "$ZIP_EXTRACT"
[[ "$(sha256 "$ZIP_PATH")" == "$ZIP_SHA" ]] || { echo "ZIP changed after verification" >&2; exit 1; }

cp -R "$APP_BUNDLE" "$DMG_ROOT/$APP_DISPLAY_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create -volname "$APP_DISPLAY_NAME $VERSION" -srcfolder "$DMG_ROOT" -format UDZO "$DMG_PATH" >/dev/null
if [[ "$MODE" == "notarized" ]]; then
  codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$DMG_PATH"
  codesign --verify --strict "$DMG_PATH"
  codesign -dvvv "$DMG_PATH" >/dev/null 2>"$ARTIFACT_DIR/codesign-dmg.txt"
  submit_notary "$DMG_PATH" dmg
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"
fi
DMG_SHA="$(sha256 "$DMG_PATH")"
DMG_MOUNT="$(mktemp -d "${TMPDIR:-/tmp}/minddesk-release-mount.XXXXXX")"
hdiutil attach -readonly -nobrowse -mountpoint "$DMG_MOUNT" "$DMG_PATH" >/dev/null
python3 - "$DMG_MOUNT" <<'PY'
import os,stat,sys
root=sys.argv[1]
if set(os.listdir(root)) != {"MindDesk.app","Applications"}: raise SystemExit("DMG has hidden or extra roots")
app=os.path.join(root,"MindDesk.app"); link=os.path.join(root,"Applications")
if not os.path.isdir(app) or os.path.islink(app): raise SystemExit("DMG app root is unsafe")
if not os.path.islink(link) or os.readlink(link) != "/Applications": raise SystemExit("DMG Applications link is wrong")
PY
compare_bundle_manifest "$DMG_MOUNT/$APP_DISPLAY_NAME.app" "$FINAL_MANIFEST"
codesign --verify --deep --strict "$DMG_MOUNT/$APP_DISPLAY_NAME.app"
[[ "$MODE" == "adhoc" ]] || { xcrun stapler validate "$DMG_MOUNT/$APP_DISPLAY_NAME.app"; spctl --assess --type execute --verbose=4 "$DMG_MOUNT/$APP_DISPLAY_NAME.app"; }
verify_final_policy
hdiutil detach "$DMG_MOUNT" >/dev/null
rmdir "$DMG_MOUNT"
DMG_MOUNT=""
[[ "$(sha256 "$DMG_PATH")" == "$DMG_SHA" ]] || { echo "DMG changed after verification" >&2; exit 1; }

cp "$NORMALIZED_PLAN" "$ARTIFACT_DIR/normalized-build-plan.json"
cp "$SOURCE_POLICY" "$ARTIFACT_DIR/source-policy-evidence.json"

if [[ -f "$RELEASE_NOTES_SOURCE" ]]; then cp "$RELEASE_NOTES_SOURCE" "$ARTIFACT_DIR/RELEASE-NOTES.md"; else printf '# %s v%s\n\nPrivate local Canvas release.\n' "$APP_DISPLAY_NAME" "$VERSION" >"$ARTIFACT_DIR/RELEASE-NOTES.md"; fi
printf '%s %s\n\nInstall by opening %s and dragging %s.app to Applications.\n' "$APP_DISPLAY_NAME" "$VERSION" "$(basename "$DMG_PATH")" "$APP_DISPLAY_NAME" >"$ARTIFACT_DIR/INSTALL.txt"

python3 - "$ARTIFACT_DIR" "$SOURCE_HEAD" "$VERSION" "$SUFFIX" "$MODE" "$RELEASE_NAME" <<'PY'
import hashlib,json,os,sys
root,head,version,suffix,mode,name=sys.argv[1:]
def digest(path): return hashlib.sha256(open(os.path.join(root,path),"rb").read()).hexdigest()
artifact_names=[("zip",f"{name}.zip"),("dmg",f"{name}.dmg")]
proof_names=[("build-provenance","build-provenance.json"),("normalized-build-plan","normalized-build-plan.json"),
("source-policy-evidence","source-policy-evidence.json"),("pre-sign-bundle-manifest","pre-sign.bundle.manifest.json"),
("final-app-bundle-manifest","final-app.bundle.manifest.json")]
artifacts=[{"kind":kind,"relativePath":path,"sha256":digest(path)} for kind,path in artifact_names]
proofs=[{"kind":kind,"relativePath":path,"sha256":digest(path)} for kind,path in proof_names]
document={"schemaVersion":1,"sourceHead":head,"version":version,"suffix":suffix,"mode":mode,"artifacts":artifacts,"proofs":proofs}
with open(os.path.join(root,"verified-artifacts.json"),"w",encoding="utf-8",newline="\n") as handle: json.dump(document,handle,sort_keys=True,separators=(",",":")); handle.write("\n")
with open(os.path.join(root,"SHA256SUMS.txt"),"w",encoding="ascii",newline="\n") as handle:
    for entry in sorted(artifacts+proofs,key=lambda value:value["relativePath"]): handle.write(f'{entry["sha256"]}  {entry["relativePath"]}\n')
PY

rm -rf -- "$PAYLOAD_DIR" "$DMG_ROOT"
[[ "$(git rev-parse HEAD)" == "$SOURCE_HEAD" ]] || { echo "Source HEAD changed during packaging" >&2; exit 1; }
[[ -z "$(git status --short)" ]] || { echo "Worktree changed during packaging" >&2; exit 1; }
mkdir -p "$RELEASE_ROOT"
mv "$STAGING_DIR" "$FINAL_RELEASE_DIR"
FINAL_ARTIFACT_DIR="$FINAL_RELEASE_DIR/artifacts"
"$ARTIFACT_VERIFIER" --artifact-dir "$FINAL_ARTIFACT_DIR" --source-head "$SOURCE_HEAD" --version "$VERSION" --suffix "$SUFFIX" --mode "$MODE"
"$WORKTREE_GUARD" --root "$ROOT_DIR"
[[ "$(git rev-parse HEAD)" == "$SOURCE_HEAD" && -z "$(git status --short)" ]] || { echo "Source identity changed before release output" >&2; exit 1; }

trap - EXIT
rm -rf -- "$BUILD_SCRATCH" "$BUILD_EVIDENCE"
echo "Verified release identity chain:"
"$ARTIFACT_VERIFIER" --artifact-dir "$FINAL_ARTIFACT_DIR" --source-head "$SOURCE_HEAD" --version "$VERSION" --suffix "$SUFFIX" --mode "$MODE"
