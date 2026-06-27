#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CI_WORKFLOW="$ROOT_DIR/.github/workflows/ci.yml"
RELEASE_WORKFLOW="$ROOT_DIR/.github/workflows/release.yml"

fail() {
  echo "$1" >&2
  exit 1
}

require_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$file" || fail "$file must contain: $needle"
}

line_of() {
  local file="$1"
  local needle="$2"
  local match
  match="$(grep -nF -- "$needle" "$file" | head -n 1 || true)"
  [[ -n "$match" ]] || fail "$file must contain: $needle"
  printf '%s\n' "${match%%:*}"
}

assert_before() {
  local file="$1"
  local earlier="$2"
  local later="$3"
  local earlier_line
  local later_line
  earlier_line="$(line_of "$file" "$earlier")"
  later_line="$(line_of "$file" "$later")"
  if [[ "$earlier_line" -ge "$later_line" ]]; then
    fail "$file must place '$earlier' before '$later'"
  fi
}

require_near() {
  local file="$1"
  local anchor="$2"
  local needle="$3"
  local window="${4:-10}"
  local start
  local end
  start="$(line_of "$file" "$anchor")"
  end=$((start + window))
  sed -n "${start},${end}p" "$file" | grep -Fq -- "$needle" || {
    fail "$file must contain near '$anchor': $needle"
  }
}

require_not_near() {
  local file="$1"
  local anchor="$2"
  local needle="$3"
  local window="${4:-12}"
  local start
  local end
  start="$(line_of "$file" "$anchor")"
  end=$((start + window))
  if sed -n "${start},${end}p" "$file" | grep -Fq -- "$needle"; then
    fail "$file must not contain near '$anchor': $needle"
  fi
}

require_contains "$CI_WORKFLOW" "bash -n script/test_release_workflow_guards.sh"
require_contains "$CI_WORKFLOW" "bash script/test_release_workflow_guards.sh"
require_contains "$CI_WORKFLOW" "bash -n script/preserve_release_failure_artifacts.sh"
require_contains "$CI_WORKFLOW" "bash -n script/verify_release_artifacts.sh"
require_contains "$CI_WORKFLOW" "bash -n script/test_build_and_run_ui_smoke_guard.sh"
require_contains "$CI_WORKFLOW" "bash -n script/test_release_artifact_verifier.sh"
require_contains "$CI_WORKFLOW" "bash -n script/test_release_failure_artifact_preserver.sh"
require_contains "$CI_WORKFLOW" "bash -n script/test_release_package_failure_diagnostics.sh"
require_contains "$CI_WORKFLOW" "bash script/test_build_and_run_ui_smoke_guard.sh"
require_contains "$CI_WORKFLOW" "bash script/test_release_artifact_verifier.sh"
require_contains "$CI_WORKFLOW" "bash script/test_release_failure_artifact_preserver.sh"
require_contains "$CI_WORKFLOW" "bash script/test_release_package_failure_diagnostics.sh"
require_contains "$CI_WORKFLOW" "./script/package_release.sh --mode adhoc --allow-adhoc"
require_near "$CI_WORKFLOW" "      - name: Package ad-hoc release smoke" 'RELEASE_PLATFORM_SUFFIX: macOS-ci-${{ github.run_id }}-${{ github.run_attempt }}'
assert_before "$CI_WORKFLOW" "./script/package_release.sh --mode adhoc --allow-adhoc" "bash script/verify_release_artifacts.sh"
require_near "$CI_WORKFLOW" "bash script/verify_release_artifacts.sh" '--artifact-dir "dist/release/MindDesk-v${VERSION}-${RELEASE_PLATFORM_SUFFIX}-adhoc/artifacts"'
require_near "$CI_WORKFLOW" "bash script/verify_release_artifacts.sh" "--mode adhoc"

require_contains "$RELEASE_WORKFLOW" "bash -n script/verify_release_artifacts.sh"
require_contains "$RELEASE_WORKFLOW" "bash -n script/preserve_release_failure_artifacts.sh"
require_contains "$RELEASE_WORKFLOW" "bash -n script/test_build_and_run_ui_smoke_guard.sh"
require_contains "$RELEASE_WORKFLOW" "bash -n script/test_release_failure_artifact_preserver.sh"
require_contains "$RELEASE_WORKFLOW" "bash -n script/test_release_package_failure_diagnostics.sh"
require_contains "$RELEASE_WORKFLOW" "bash script/test_build_and_run_ui_smoke_guard.sh"
require_contains "$RELEASE_WORKFLOW" "bash script/test_release_failure_artifact_preserver.sh"
require_contains "$RELEASE_WORKFLOW" "bash script/test_release_package_failure_diagnostics.sh"
require_contains "$RELEASE_WORKFLOW" "bash -n script/test_release_workflow_guards.sh"
require_contains "$RELEASE_WORKFLOW" "bash script/test_release_workflow_guards.sh"
require_contains "$RELEASE_WORKFLOW" "      - name: Set release artifact suffix"
require_contains "$RELEASE_WORKFLOW" "          echo \"RELEASE_PLATFORM_SUFFIX=macOS-\${ARCH}\" >>\"\$GITHUB_ENV\""
require_contains "$RELEASE_WORKFLOW" "          echo \"release_platform_suffix=macOS-\${ARCH}\" >>\"\$GITHUB_OUTPUT\""

require_contains "$RELEASE_WORKFLOW" "      - name: Verify notarized release artifacts"
require_contains "$RELEASE_WORKFLOW" "bash script/verify_release_artifacts.sh"
require_near "$RELEASE_WORKFLOW" "      - name: Verify notarized release artifacts" "bash script/verify_release_artifacts.sh"
require_near "$RELEASE_WORKFLOW" "bash script/verify_release_artifacts.sh" '--artifact-dir "dist/release/MindDesk-v${VERSION}-${RELEASE_PLATFORM_SUFFIX}/artifacts"'
require_near "$RELEASE_WORKFLOW" "bash script/verify_release_artifacts.sh" '--version "$VERSION"'
require_near "$RELEASE_WORKFLOW" "bash script/verify_release_artifacts.sh" '--suffix "$RELEASE_PLATFORM_SUFFIX"'
require_near "$RELEASE_WORKFLOW" "bash script/verify_release_artifacts.sh" "--mode notarized"
require_contains "$RELEASE_WORKFLOW" "      - name: Upload release artifacts"
require_near "$RELEASE_WORKFLOW" "      - name: Upload release artifacts" 'name: minddesk-${{ steps.release_suffix.outputs.release_platform_suffix }}-release'
require_near "$RELEASE_WORKFLOW" "      - name: Upload release artifacts" "dist/release/*/artifacts/*.zip"
require_near "$RELEASE_WORKFLOW" "      - name: Upload release artifacts" "dist/release/*/artifacts/*.dmg"
require_near "$RELEASE_WORKFLOW" "      - name: Upload release artifacts" "dist/release/*/artifacts/SHA256SUMS.txt"
require_near "$RELEASE_WORKFLOW" "      - name: Upload release artifacts" "dist/release/*/artifacts/INSTALL.txt"
require_near "$RELEASE_WORKFLOW" "      - name: Upload release artifacts" "dist/release/*/artifacts/RELEASE-NOTES.md"
require_not_near "$RELEASE_WORKFLOW" "      - name: Upload release artifacts" "dist/release/*/artifacts/*.txt"
require_not_near "$RELEASE_WORKFLOW" "      - name: Upload release artifacts" "dist/release/*/artifacts/*.md"
require_not_near "$RELEASE_WORKFLOW" "      - name: Upload release artifacts" "dist/release/*/artifacts/*.json"
require_not_near "$RELEASE_WORKFLOW" "      - name: Upload release artifacts" "dist/release/*/artifacts/*.plist"
require_contains "$RELEASE_WORKFLOW" "      - name: Upload release diagnostics"
require_near "$RELEASE_WORKFLOW" "      - name: Upload release diagnostics" 'name: minddesk-${{ steps.release_suffix.outputs.release_platform_suffix }}-release-diagnostics'
require_near "$RELEASE_WORKFLOW" "      - name: Upload release diagnostics" 'if: ${{ always() }}'
require_near "$RELEASE_WORKFLOW" "      - name: Upload release diagnostics" "if-no-files-found: ignore"
require_contains "$RELEASE_WORKFLOW" "dist/release/*/artifacts/notary-*.json"
require_contains "$RELEASE_WORKFLOW" "dist/release/*/artifacts/notary-*.stderr"
require_contains "$RELEASE_WORKFLOW" "dist/release/*/artifacts/codesign-*.txt"
require_contains "$RELEASE_WORKFLOW" "dist/release/*/artifacts/codesign-*.plist"

assert_before "$RELEASE_WORKFLOW" "      - name: Build, sign, notarize, and staple release artifacts" "      - name: Verify notarized release artifacts"
assert_before "$RELEASE_WORKFLOW" "      - name: Build, sign, notarize, and staple release artifacts" "      - name: Upload release diagnostics"
assert_before "$RELEASE_WORKFLOW" "      - name: Verify notarized release artifacts" "      - name: Upload release artifacts"
assert_before "$RELEASE_WORKFLOW" "      - name: Verify notarized release artifacts" "      - name: Create draft GitHub Release"
assert_before "$RELEASE_WORKFLOW" "      - name: Upload release diagnostics" "      - name: Create draft GitHub Release"

echo "Release workflow guard tests passed."
