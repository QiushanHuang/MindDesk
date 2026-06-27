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
  Package.resolved
  Sources
  Tests
  script
  .github
  README.md
  VERSION
  docs
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
    Package.swift|Package.resolved|README.md|VERSION)
      return 0
      ;;
    Sources/*.swift|Tests/*.swift|script/*.sh|.github/workflows/*.yml|.github/workflows/*.yaml|docs/*.md)
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

if [[ -n "$tracked_changes" || -n "$untracked_files" || -n "$ignored_critical_files" ]]; then
  exit 1
fi

echo "Release worktree ok: no tracked, untracked, or ignored release-critical changes."
