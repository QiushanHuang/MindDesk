#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY="$ROOT_DIR/script/s0_private_canvas_policy.sh"
VERIFIER="$ROOT_DIR/script/verify_s0_private_canvas.sh"

fail() {
  printf 'self-test failure: %s\n' "$1" >&2
  exit 1
}

[[ -r "$POLICY" ]] || fail "shared S0 policy is missing"
[[ -x "$VERIFIER" ]] || fail "S0 verifier is missing or not executable"

# shellcheck source=s0_private_canvas_policy.sh
source "$POLICY"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/minddesk-s0-verifier-selftest.XXXXXX")"
cleanup() {
  case "$TMP_ROOT" in
    "${TMPDIR:-/tmp}"/minddesk-s0-verifier-selftest.??????)
      [[ -d "$TMP_ROOT" && ! -L "$TMP_ROOT" ]] && rm -rf -- "$TMP_ROOT"
      ;;
    *) return 1 ;;
  esac
}
trap cleanup EXIT

FAKE_BIN="$TMP_ROOT/fake-bin"
SWIFT_LOG="$TMP_ROOT/swift.log"
mkdir -p "$FAKE_BIN"
printf '#!/usr/bin/env bash\nprintf "swift invoked\\n" >>"%s"\nexit 97\n' "$SWIFT_LOG" >"$FAKE_BIN/swift"
chmod 0755 "$FAKE_BIN/swift"

make_repo() {
  local name="$1"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo/Sources/MindDesk" "$repo/Sources/MindDeskCore"
  cp "$ROOT_DIR/Package.swift" "$repo/Package.swift"
  printf '%s\n' "$repo"
}

assert_no_swiftpm() {
  [[ ! -s "$SWIFT_LOG" ]] || fail "package-manifest gate invoked SwiftPM"
}

assert_package_passes() {
  local repo="$1"
  : >"$SWIFT_LOG"
  if ! PATH="$FAKE_BIN:$PATH" "$VERIFIER" --repo-root "$repo" --package-manifest-only >"$TMP_ROOT/out" 2>&1; then
    sed -n '1,120p' "$TMP_ROOT/out" >&2
    fail "expected package-manifest-only success"
  fi
  assert_no_swiftpm
}

assert_package_fails() {
  local repo="$1"
  local expected="$2"
  : >"$SWIFT_LOG"
  if PATH="$FAKE_BIN:$PATH" "$VERIFIER" --repo-root "$repo" --package-manifest-only >"$TMP_ROOT/out" 2>&1; then
    fail "expected package-manifest-only failure"
  fi
  grep -Fq "$expected" "$TMP_ROOT/out" || {
    sed -n '1,120p' "$TMP_ROOT/out" >&2
    fail "expected failure containing: $expected"
  }
  assert_no_swiftpm
}

valid_repo="$(make_repo 'valid repo with spaces')"
assert_package_passes "$valid_repo"

for suffix in \
  '6.swift' \
  '6.0.swift' \
  '6.0.1.swift' \
  'next.swift' \
  $'line\nbreak.swift' \
  $'control-\001.swift'; do
  repo="$(make_repo "versioned-$RANDOM")"
  printf '// forbidden alternate manifest\n' >"$repo/Package@swift-$suffix"
  assert_package_fails "$repo" 'version-specific package manifest is forbidden'
done

repo="$(make_repo 'symlink-versioned')"
printf '// alternate\n' >"$TMP_ROOT/alternate-manifest"
ln -s "$TMP_ROOT/alternate-manifest" "$repo/Package@swift-6.swift"
assert_package_fails "$repo" 'version-specific package manifest is forbidden'

repo="$(make_repo 'symlink-primary')"
mv "$repo/Package.swift" "$TMP_ROOT/primary-manifest"
ln -s "$TMP_ROOT/primary-manifest" "$repo/Package.swift"
assert_package_fails "$repo" 'Package.swift must be one regular non-symlink file'

repo="$(make_repo 'resolved-pin')"
printf '{"pins":[]}\n' >"$repo/Package.resolved"
assert_package_fails "$repo" 'Package.resolved is forbidden'

for payload in \
  $'\nimport Foundation\nlet _ = FileManager.default\n' \
  $'\nimport Darwin\nlet _ = open("/tmp/x", 0)\n' \
  $'\nlet _ = Process()\n' \
  $'\nlet _ = URLSession.shared\n' \
  $'\nlet _ = ProcessInfo.processInfo.environment\n' \
  $'\nlet _ = CommandLine.arguments\n' \
  $'\nlet package = Package(name: "Bad", dependencies: [.package(url: "https://example.invalid/x", from: "1.0.0")])\n'; do
  repo="$(make_repo "malicious-$RANDOM")"
  printf '%s' "$payload" >>"$repo/Package.swift"
  assert_package_fails "$repo" 'Package.swift does not match the frozen declarative manifest'
done

source_repo="$(make_repo 'source-policy')"
printf 'import SwiftUI\nimport MindDeskCore\nlet value = MindDeskJSONDocumentKind.manifest\n' >"$source_repo/Sources/MindDesk/Allowed.swift"
printf 'import Foundation\npublic let value = 1\n' >"$source_repo/Sources/MindDeskCore/Allowed.swift"
s0_policy_check_source_tree "$source_repo" >/dev/null || fail "allowed source fixture was rejected"

printf 'import Network\n' >"$source_repo/Sources/MindDesk/Forbidden.swift"
if s0_policy_check_source_tree "$source_repo" >/dev/null 2>&1; then
  fail "unknown production import was accepted"
fi
rm "$source_repo/Sources/MindDesk/Forbidden.swift"

printf 'let marker = "Review Agent Proposal"\n' >"$source_repo/Sources/MindDesk/Forbidden.swift"
if s0_policy_check_source_tree "$source_repo" >/dev/null 2>&1; then
  fail "removed runtime marker was accepted"
fi
rm "$source_repo/Sources/MindDesk/Forbidden.swift"

printf 'let value: MindDeskProposalEnvelope? = nil\n' >"$source_repo/Sources/MindDesk/Forbidden.swift"
if s0_policy_check_source_tree "$source_repo" >/dev/null 2>&1; then
  fail "historical DTO reference escaped into app source"
fi
rm "$source_repo/Sources/MindDesk/Forbidden.swift"

touch "$source_repo/Sources/MindDesk/CanvasCodexAgentSidebar.swift"
if s0_policy_check_source_tree "$source_repo" >/dev/null 2>&1; then
  fail "deleted app basename was accepted"
fi

artifact="$TMP_ROOT/artifact.txt"
for marker in "${S0_DENIED_ARTIFACT_STRINGS[@]}"; do
  printf '%s\n' "$marker" >"$artifact"
  grep -Fq "$marker" "$artifact" || fail "artifact marker fixture was not detected: $marker"
done
printf 'Review Agent Proposals\n' >"$artifact"
if grep -Fxq 'Review Agent Proposal' "$artifact"; then
  fail "near-miss artifact marker was treated as an exact marker"
fi

: >"$SWIFT_LOG"
if PATH="$FAKE_BIN:$PATH" "$VERIFIER" \
  --repo-root "$valid_repo" \
  --scratch-path relative \
  --configuration release \
  --build-description /tmp/description.json \
  --evidence-dir /tmp/evidence \
  --binary /tmp/MindDesk >"$TMP_ROOT/out" 2>&1; then
  fail "relative Release scratch was accepted"
fi
grep -Fq -- '--scratch-path must be absolute' "$TMP_ROOT/out" || fail "relative scratch did not fail at argument validation"
assert_no_swiftpm

: >"$SWIFT_LOG"
if PATH="$FAKE_BIN:$PATH" "$VERIFIER" \
  --repo-root "$valid_repo" \
  --scratch-path /tmp/scratch \
  --configuration debug \
  --build-description /tmp/description.json \
  --evidence-dir /tmp/evidence \
  --binary /tmp/MindDesk >"$TMP_ROOT/out" 2>&1; then
  fail "Debug configuration was accepted by Release verifier"
fi
grep -Fq -- '--configuration must be release' "$TMP_ROOT/out" || fail "Debug configuration did not fail closed"
assert_no_swiftpm

printf 'S0 private Canvas verifier self-test: PASS\n'
