#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' <"$ROOT_DIR/VERSION")"
README="$ROOT_DIR/README.md"
RELEASE_NOTES="$ROOT_DIR/docs/releases/v$VERSION.md"

fail() {
  echo "$1" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "Missing required file: $1"
}

require_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "$file must contain: $needle"
}

reject_contains() {
  local file="$1"
  local needle="$2"
  ! grep -Fq "$needle" "$file" || fail "$file contains stale text: $needle"
}

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "VERSION must be semantic x.y.z, got: ${VERSION:-<empty>}"
require_file "$README"
require_file "$RELEASE_NOTES"

require_contains "$README" "release-v$VERSION"
require_contains "$README" "Current release: \`v$VERSION\`"
require_contains "$README" "docs/releases/v$VERSION.md"
require_contains "$README" "MindDesk-v$VERSION-macOS"
require_contains "$README" "MindDesk-v$VERSION-macOS-arm64.dmg"
require_contains "$README" "当前版本：\`v$VERSION\`"
reject_contains "$README" "Move from ad-hoc signed builds toward notarized Developer ID releases"
reject_contains "$README" "从 ad-hoc signed 构建升级到 Developer ID notarized 正式发布"

require_contains "$RELEASE_NOTES" "# MindDesk v$VERSION"
require_contains "$RELEASE_NOTES" "## Distribution"
require_contains "$RELEASE_NOTES" "## Validation"
reject_contains "$RELEASE_NOTES" "should be validated"
reject_contains "$RELEASE_NOTES" "Image-Derived Update Table"

echo "Release metadata ok for v$VERSION"
