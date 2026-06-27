#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_DIR=""
RELEASE_ROOT=""
RELEASE_NAME=""

usage() {
  cat <<USAGE
Usage: $0 --artifact-dir DIR --release-root DIR --release-name NAME

Copies package_release.sh staging artifacts to a stable failed-artifacts directory
so release workflow diagnostics can be uploaded after a failed packaging run.
USAGE
}

usage_error() {
  echo "$1" >&2
  usage >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-dir)
      [[ $# -ge 2 ]] || usage_error "Missing value for --artifact-dir"
      ARTIFACT_DIR="$2"
      shift 2
      ;;
    --release-root)
      [[ $# -ge 2 ]] || usage_error "Missing value for --release-root"
      RELEASE_ROOT="$2"
      shift 2
      ;;
    --release-name)
      [[ $# -ge 2 ]] || usage_error "Missing value for --release-name"
      RELEASE_NAME="$2"
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
[[ -n "$RELEASE_ROOT" ]] || usage_error "Missing required option: --release-root"
[[ -n "$RELEASE_NAME" ]] || usage_error "Missing required option: --release-name"
[[ "$RELEASE_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || usage_error "release name may contain only letters, numbers, dots, underscores, and hyphens."

if [[ ! -d "$ARTIFACT_DIR" ]]; then
  exit 0
fi

mkdir -p "$RELEASE_ROOT"

target_base="$RELEASE_ROOT/$RELEASE_NAME-failed-artifacts"
target="$target_base"
suffix=2
while [[ -e "$target" ]]; do
  target="$target_base-$suffix"
  suffix=$((suffix + 1))
done

target_artifacts="$target/artifacts"
mkdir -p "$target_artifacts"
cp -R "$ARTIFACT_DIR"/. "$target_artifacts"/

echo "$target_artifacts"
