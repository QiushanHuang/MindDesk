#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/minddesk-package-failure-diagnostics.XXXXXX")"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  echo "$1" >&2
  exit 1
}

assert_file_contains() {
  local file="$1"
  local expected="$2"
  [[ -f "$file" ]] || fail "Missing expected file: $file"
  grep -Fq "$expected" "$file" || fail "$file must contain: $expected"
}

write_fake_tool() {
  local name="$1"
  local body="$2"
  local path="$TMP_ROOT/fake-bin/$name"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$body" >"$path"
  chmod +x "$path"
}

fixture="$TMP_ROOT/fixture repo"
mkdir -p \
  "$fixture/script" \
  "$fixture/docs/releases" \
  "$fixture/Sources/MindDesk/Resources" \
  "$TMP_ROOT/fake-bin"

cp "$ROOT_DIR/script/package_release.sh" "$fixture/script/package_release.sh"
cp "$ROOT_DIR/script/preserve_release_failure_artifacts.sh" "$fixture/script/preserve_release_failure_artifacts.sh"
cat >"$fixture/script/verify_release_worktree.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$fixture/script/verify_release_worktree.sh"

printf '1.2.3\n' >"$fixture/VERSION"
cat >"$fixture/docs/releases/v1.2.3.md" <<'MD'
# MindDesk v1.2.3

## Distribution

- Fixture release notes.

## Validation

- Fixture validation notes.
MD
cat >"$fixture/script/release.entitlements" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
PLIST
printf 'icon fixture\n' >"$fixture/Sources/MindDesk/Resources/AppIcon.icns"

write_fake_tool swift '#!/usr/bin/env bash
set -euo pipefail
build_dir="$PWD/.fake-build/release"
mkdir -p "$build_dir/MindDesk_MindDesk.bundle"
printf "#!/usr/bin/env bash\nexit 0\n" >"$build_dir/MindDesk"
chmod +x "$build_dir/MindDesk"
printf "resource bundle\n" >"$build_dir/MindDesk_MindDesk.bundle/resource.txt"
for arg in "$@"; do
  if [[ "$arg" == "--show-bin-path" ]]; then
    printf "%s\n" "$build_dir"
    exit 0
  fi
done
exit 0'

write_fake_tool security '#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "find-identity" ]]; then
  printf "  1) ABCDEF \"Developer ID Application: Fixture (TEAMID)\"\n"
  exit 0
fi
exit 0'

write_fake_tool xcrun '#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--find" ]]; then
  case "${2:-}" in
    notarytool|stapler)
      printf "/usr/bin/%s\n" "$2"
      exit 0
      ;;
  esac
  exit 1
fi

tool="${1:-}"
shift || true
case "$tool" in
  notarytool)
    command="${1:-}"
    shift || true
    case "$command" in
      history)
        printf "{\"history\":[]}\n"
        exit 0
        ;;
      submit)
        artifact="${1:-}"
        if [[ "$artifact" == *.dmg ]]; then
          printf "{\"id\":\"dmg-submission-id\",\"status\":\"Invalid\"}\n"
          printf "fixture dmg notarization rejected\n" >&2
          exit 1
        fi
        printf "{\"id\":\"app-submission-id\",\"status\":\"Accepted\"}\n"
        exit 0
        ;;
      log)
        submission="${1:-}"
        printf "{\"id\":\"%s\",\"issues\":[{\"severity\":\"error\",\"message\":\"fixture issue\"}]}\n" "$submission"
        exit 0
        ;;
    esac
    ;;
  stapler)
    exit 0
    ;;
esac
exit 1'

write_fake_tool codesign '#!/usr/bin/env bash
set -euo pipefail
display=0
target=""
for arg in "$@"; do
  [[ "$arg" == "-dvvv" ]] && display=1
  target="$arg"
done
if [[ "$display" -eq 1 ]]; then
  if [[ "$target" == *.app ]]; then
    cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
PLIST
  fi
  printf "Authority=Developer ID Application: Fixture (TEAMID)\n" >&2
  printf "TeamIdentifier=TEAMID\n" >&2
fi
exit 0'

write_fake_tool ditto '#!/usr/bin/env bash
set -euo pipefail
dest=""
for arg in "$@"; do
  dest="$arg"
done
mkdir -p "$(dirname "$dest")"
printf "archive fixture\n" >"$dest"'

write_fake_tool hdiutil '#!/usr/bin/env bash
set -euo pipefail
dest=""
for arg in "$@"; do
  dest="$arg"
done
mkdir -p "$(dirname "$dest")"
printf "dmg fixture\n" >"$dest"'

write_fake_tool spctl '#!/usr/bin/env bash
set -euo pipefail
exit 0'

output_file="$TMP_ROOT/package-output.txt"
set +e
(
  cd "$fixture"
  PATH="$TMP_ROOT/fake-bin:$PATH" \
    RELEASE_PLATFORM_SUFFIX="ci-failure" \
    bash "$fixture/script/package_release.sh" \
      --mode notarized \
      --identity "Developer ID Application: Fixture (TEAMID)" \
      --team-id TEAMID \
      --notary-profile fixture-profile
) >"$output_file" 2>&1
package_status=$?
set -e

if [[ "$package_status" -eq 0 ]]; then
  cat "$output_file" >&2
  fail "Expected notarized package fixture to fail at DMG notarization"
fi

assert_file_contains "$output_file" "Notarization failed for dmg"
assert_file_contains "$output_file" "fixture dmg notarization rejected"

release_root="$fixture/dist/release"
release_name="MindDesk-v1.2.3-ci-failure"
preserved_artifacts="$release_root/$release_name-failed-artifacts/artifacts"
[[ -d "$preserved_artifacts" ]] || {
  cat "$output_file" >&2
  fail "Missing expected preserved diagnostics directory: $preserved_artifacts"
}

assert_file_contains "$preserved_artifacts/$release_name.zip" "archive fixture"
assert_file_contains "$preserved_artifacts/$release_name.dmg" "dmg fixture"
assert_file_contains "$preserved_artifacts/notary-submit-app.json" '"status":"Accepted"'
assert_file_contains "$preserved_artifacts/notary-submit-dmg.json" '"status":"Invalid"'
assert_file_contains "$preserved_artifacts/notary-submit-dmg.json" "dmg-submission-id"
assert_file_contains "$preserved_artifacts/notary-log-dmg.json" "dmg-submission-id"
assert_file_contains "$preserved_artifacts/notary-submit-dmg.stderr" "fixture dmg notarization rejected"
assert_file_contains "$preserved_artifacts/codesign-app.txt" "Developer ID Application"
assert_file_contains "$preserved_artifacts/codesign-dmg.txt" "TeamIdentifier=TEAMID"
assert_file_contains "$preserved_artifacts/codesign-entitlements-app.plist" "<plist version=\"1.0\">"

[[ ! -d "$release_root/$release_name" ]] || fail "Failed package should not publish final release directory"
if find "$release_root" -name ".staging-*" -print -quit | grep -q .; then
  find "$release_root" -name ".staging-*" -print >&2
  fail "Staging release directories should be cleaned after failure"
fi

echo "Release package failure diagnostics tests passed."
