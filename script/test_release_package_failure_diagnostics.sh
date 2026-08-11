#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/minddesk-package-fail.XXXXXX")"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
FIXTURE="$TMP_ROOT/repo"
LOG="$TMP_ROOT/calls.log"
mkdir -p "$FIXTURE/script" "$FIXTURE/Sources/MindDesk/Resources" "$TMP_ROOT/bin"
cp "$ROOT_DIR/script/package_release.sh" "$FIXTURE/script/package_release.sh"
printf '1.2.3\n' >"$FIXTURE/VERSION"
printf 'icon\n' >"$FIXTURE/Sources/MindDesk/Resources/AppIcon.icns"

for name in verify_release_worktree.sh verify_release_artifacts.sh preserve_release_failure_artifacts.sh; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$FIXTURE/script/$name"
  chmod +x "$FIXTURE/script/$name"
done
cat >"$FIXTURE/script/verify_s0_private_canvas.sh" <<'SH'
#!/usr/bin/env bash
printf 's0:%s\n' "$*" >>"$PACKAGE_TEST_LOG"
if [[ "$*" == *"--package-manifest-only"* ]]; then
  echo "fixture manifest rejection" >&2
  exit 41
fi
exit 0
SH
chmod +x "$FIXTURE/script/verify_s0_private_canvas.sh"
cat >"$TMP_ROOT/bin/swift" <<'SH'
#!/usr/bin/env bash
printf 'swift:%s\n' "$*" >>"$PACKAGE_TEST_LOG"
exit 99
SH
chmod +x "$TMP_ROOT/bin/swift"

git -C "$FIXTURE" init -q
git -C "$FIXTURE" config user.email test@example.com
git -C "$FIXTURE" config user.name Test
git -C "$FIXTURE" add .
git -C "$FIXTURE" commit -q -m fixture

set +e
(cd "$FIXTURE" && PACKAGE_TEST_LOG="$LOG" PATH="$TMP_ROOT/bin:$PATH" RELEASE_PLATFORM_SUFFIX=fixture bash script/package_release.sh --mode adhoc --allow-adhoc) >"$TMP_ROOT/output" 2>&1
status=$?
set -e
[[ "$status" -eq 41 ]] || { cat "$TMP_ROOT/output" >&2; echo "Expected manifest gate status 41, got $status" >&2; exit 1; }
grep -Fq 's0:--repo-root' "$LOG"
grep -Fq -- '--package-manifest-only' "$LOG"
if grep -Fq 'swift:' "$LOG"; then echo "SwiftPM ran after a rejected package manifest" >&2; exit 1; fi
[[ ! -e "$FIXTURE/dist" ]] || { echo "Rejected package created release output" >&2; exit 1; }

set +e
(cd "$FIXTURE" && RELEASE_PLATFORM_SUFFIX='bad/slash' bash script/package_release.sh --mode adhoc --allow-adhoc) >"$TMP_ROOT/suffix-output" 2>&1
suffix_status=$?
set -e
[[ "$suffix_status" -ne 0 ]] || { echo "Invalid suffix unexpectedly passed" >&2; exit 1; }
grep -Fqi 'RELEASE_PLATFORM_SUFFIX may contain only' "$TMP_ROOT/suffix-output"

echo "Release package failure diagnostics tests passed."
