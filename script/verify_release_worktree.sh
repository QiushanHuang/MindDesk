#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<USAGE
Usage: $0 [--root PATH]

Verifies that release-critical source, test, script, docs, and workflow files are
fully represented in git before a local or CI release gate runs.

Options:
  --root PATH   Repository root to inspect. Defaults to this checkout.
  -h, --help    Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --root" >&2
        usage >&2
        exit 2
      fi
      ROOT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Release worktree guard requires a git worktree: $ROOT_DIR" >&2
  exit 3
fi

RELEASE_CRITICAL_PATHS=(
  Package.swift
  'Package@swift-*.swift'
  Package.resolved
  Sources
  Tests
  script
  .github
  README.md
  CHANGELOG.md
  VERSION
  docs
  Fixtures
  fixtures
)

print_list() {
  local heading="$1"
  local body="$2"
  echo "$heading" >&2
  printf '%s\n' "$body" | sed '/^$/d; s/^/  - /' >&2
}

append_line() {
  local current="$1"
  local item="$2"
  if [[ -n "$current" ]]; then
    printf '%s\n%s\n' "$current" "$item"
  else
    printf '%s\n' "$item"
  fi
}

is_ignored_release_critical_file() {
  local path="$1"
  case "$path" in
    Package.swift|Package@swift-*.swift|Package.resolved|README.md|CHANGELOG.md|VERSION)
      return 0
      ;;
    Sources/*|Tests/*|script/*|.github/*|docs/*|Fixtures/*|fixtures/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

tracked_changes="$(
  {
    git -C "$ROOT_DIR" diff --name-only -- "${RELEASE_CRITICAL_PATHS[@]}"
    git -C "$ROOT_DIR" diff --cached --name-only -- "${RELEASE_CRITICAL_PATHS[@]}"
  } | sort -u
)"

if [[ -n "$tracked_changes" ]]; then
  print_list "Tracked release-critical changes must be committed before release:" "$tracked_changes"
fi

untracked_files="$(git -C "$ROOT_DIR" ls-files --others --exclude-standard -- "${RELEASE_CRITICAL_PATHS[@]}")"

if [[ -n "$untracked_files" ]]; then
  print_list "Untracked release-critical files must be added and committed, or removed before release:" "$untracked_files"
fi

ignored_candidates="$(git -C "$ROOT_DIR" ls-files --others --ignored --exclude-standard -- "${RELEASE_CRITICAL_PATHS[@]}")"
ignored_critical_files=""
while IFS= read -r ignored_file; do
  [[ -n "$ignored_file" ]] || continue
  if is_ignored_release_critical_file "$ignored_file"; then
    ignored_critical_files="$(append_line "$ignored_critical_files" "$ignored_file")"
  fi
done <<<"$ignored_candidates"

if [[ -n "$ignored_critical_files" ]]; then
  print_list "Ignored release-critical files must be added or removed before release:" "$ignored_critical_files"
fi

symlink_files=""
while IFS= read -r -d '' tracked_path; do
  [[ -L "$ROOT_DIR/$tracked_path" ]] || continue
  symlink_files="$(append_line "$symlink_files" "$tracked_path")"
done < <(git -C "$ROOT_DIR" ls-files -z -- "${RELEASE_CRITICAL_PATHS[@]}")
while IFS= read -r candidate; do
  [[ -n "$candidate" && -L "$ROOT_DIR/$candidate" ]] || continue
  symlink_files="$(append_line "$symlink_files" "$candidate")"
done <<<"$(printf '%s\n%s\n' "$untracked_files" "$ignored_candidates" | sort -u)"

versioned_manifests=""
while IFS= read -r -d '' manifest; do
  versioned_manifests="$(append_line "$versioned_manifests" "${manifest#$ROOT_DIR/}")"
done < <(find -P "$ROOT_DIR" -mindepth 1 -maxdepth 1 -name 'Package@swift-*.swift' -print0)

if [[ -n "$symlink_files" ]]; then
  print_list "Release-critical symlinks are forbidden:" "$(printf '%s\n' "$symlink_files" | sort -u)"
fi
if [[ -n "$versioned_manifests" ]]; then
  print_list "Version-specific package manifests are forbidden:" "$versioned_manifests"
fi

if [[ -n "$tracked_changes" || -n "$untracked_files" || -n "$ignored_critical_files" || -n "$symlink_files" || -n "$versioned_manifests" ]]; then
  exit 1
fi

echo "Release worktree ok: no tracked, untracked, or ignored release-critical changes."
