#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_SCRIPT="$ROOT_DIR/script/build_and_run.sh"

fail() {
  echo "$1" >&2
  exit 1
}

require_contains() {
  local needle="$1"
  grep -Fq -- "$needle" "$RUN_SCRIPT" || fail "$RUN_SCRIPT must contain: $needle"
}

line_of() {
  local needle="$1"
  local match
  match="$(grep -nF -- "$needle" "$RUN_SCRIPT" | head -n 1 || true)"
  [[ -n "$match" ]] || fail "$RUN_SCRIPT must contain: $needle"
  printf '%s\n' "${match%%:*}"
}

assert_before() {
  local earlier="$1"
  local later="$2"
  local earlier_line
  local later_line
  earlier_line="$(line_of "$earlier")"
  later_line="$(line_of "$later")"
  if [[ "$earlier_line" -ge "$later_line" ]]; then
    fail "$RUN_SCRIPT must place '$earlier' before '$later'"
  fi
}

require_contains "MINDDESK_APPLICATION_SUPPORT_DIR"
require_contains "mktemp -d"
require_contains "--ui-smoke|ui-smoke)"
require_contains "--env \"MINDDESK_APPLICATION_SUPPORT_DIR="
require_contains 'usage: $0 [run|--debug|--logs|--telemetry|--verify|--verify-bundle|--ui-smoke]'
assert_before "mktemp -d" "--env \"MINDDESK_APPLICATION_SUPPORT_DIR="

echo "Build/run UI smoke guard tests passed."
