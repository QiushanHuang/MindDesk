#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="$ROOT_DIR/script/package_release.sh"
CI="$ROOT_DIR/.github/workflows/ci.yml"
RELEASE="$ROOT_DIR/.github/workflows/release.yml"
fail() { echo "$1" >&2; exit 1; }
contains() { grep -Fq -- "$2" "$1" || fail "$1 must contain: $2"; }
forbids() { ! grep -Fq -- "$2" "$1" || fail "$1 must not contain: $2"; }
line_of() { grep -nF -- "$2" "$1" | head -1 | cut -d: -f1; }
before() {
  local a b; a="$(line_of "$1" "$2")"; b="$(line_of "$1" "$3")"
  [[ -n "$a" && -n "$b" && "$a" -lt "$b" ]] || fail "$1 must place '$2' before '$3'"
}

for file in "$PACKAGE" "$CI" "$RELEASE"; do
  contains "$file" "--package-manifest-only"
  before "$file" "--package-manifest-only" "swift build"
  forbids "$file" "dist/**"
  forbids "$file" "--clobber"
done

contains "$PACKAGE" 'SOURCE_HEAD="$(git rev-parse HEAD)"'
contains "$PACKAGE" 'BUILD_SCRATCH="$(mktemp -d'
contains "$PACKAGE" 'BUILD_EVIDENCE="$(mktemp -d'
contains "$PACKAGE" '--scratch-path "$BUILD_SCRATCH"'
contains "$PACKAGE" '--evidence-dir "$BUILD_EVIDENCE"'
contains "$PACKAGE" 'build-provenance.json'
contains "$PACKAGE" 'pre-sign.bundle.manifest.json'
contains "$PACKAGE" 'final-app.bundle.manifest.json'
contains "$PACKAGE" 'verified-artifacts.json'
contains "$PACKAGE" 'hdiutil attach -readonly -nobrowse'
contains "$PACKAGE" 'compare_bundle_manifest "$ZIP_EXTRACT/$APP_DISPLAY_NAME.app"'
contains "$PACKAGE" 'compare_bundle_manifest "$DMG_MOUNT/$APP_DISPLAY_NAME.app"'
forbids "$PACKAGE" '"$ROOT_DIR/.build'

for workflow in "$CI" "$RELEASE"; do
  contains "$workflow" 'SOURCE_HEAD=$(git rev-parse HEAD)'
  contains "$workflow" 'id: verified_release_artifacts'
  contains "$workflow" '--scratch-path "$scratch"'
  contains "$workflow" '--evidence-dir "$evidence"'
  contains "$workflow" 'build_provenance_path'
  contains "$workflow" 'normalized_plan_path'
  contains "$workflow" 'source_policy_path'
  contains "$workflow" 'pre_sign_manifest_path'
  contains "$workflow" 'final_app_manifest_path'
  contains "$workflow" 'verified_artifacts_path'
  contains "$workflow" 'checksums_path'
  contains "$workflow" 'build_provenance_sha256'
  contains "$workflow" 'normalized_plan_sha256'
  contains "$workflow" 'source_policy_sha256'
  contains "$workflow" 'pre_sign_manifest_sha256'
  contains "$workflow" 'final_app_manifest_sha256'
  contains "$workflow" 'verified_artifacts_sha256'
  contains "$workflow" 'checksums_sha256'
  forbids "$workflow" 'dist/release/*'
done

before "$CI" 'Direct private Release evidence' 'Debug and Release suites'
before "$CI" 'Debug and Release suites' 'Package ad-hoc release smoke'
before "$CI" 'Recheck exported release digests' 'Upload verified release bundle'
before "$RELEASE" 'Direct private Release evidence' 'Build, sign, notarize, and staple verified release'
before "$RELEASE" 'Recheck exported release digests' 'Upload verified release bundle'
contains "$RELEASE" 'refusing to replace assets'

echo "Release workflow guard tests passed."
