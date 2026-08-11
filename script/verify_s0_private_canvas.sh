#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY="$SCRIPT_DIR/s0_private_canvas_policy.sh"
[[ -r "$POLICY" && ! -L "$POLICY" ]] || {
  printf 'shared S0 policy is missing or unsafe: %s\n' "$POLICY" >&2
  exit 1
}
# shellcheck source=s0_private_canvas_policy.sh
source "$POLICY"

fail() {
  printf 'S0 verification failed: %s\n' "$1" >&2
  exit 1
}

usage_error() {
  printf 'S0 verifier usage error: %s\n' "$1" >&2
  exit 2
}

sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

REPO_ROOT=""
SCRATCH_PATH=""
CONFIGURATION=""
BUILD_DESCRIPTION=""
EVIDENCE_DIR=""
BINARY=""
APP_BUNDLE=""
PACKAGE_MANIFEST_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      [[ $# -ge 2 && -z "$REPO_ROOT" ]] || usage_error "--repo-root requires one value and may appear once"
      REPO_ROOT="$2"
      shift 2
      ;;
    --scratch-path)
      [[ $# -ge 2 && -z "$SCRATCH_PATH" ]] || usage_error "--scratch-path requires one value and may appear once"
      SCRATCH_PATH="$2"
      shift 2
      ;;
    --configuration)
      [[ $# -ge 2 && -z "$CONFIGURATION" ]] || usage_error "--configuration requires one value and may appear once"
      CONFIGURATION="$2"
      shift 2
      ;;
    --build-description)
      [[ $# -ge 2 && -z "$BUILD_DESCRIPTION" ]] || usage_error "--build-description requires one value and may appear once"
      BUILD_DESCRIPTION="$2"
      shift 2
      ;;
    --evidence-dir)
      [[ $# -ge 2 && -z "$EVIDENCE_DIR" ]] || usage_error "--evidence-dir requires one value and may appear once"
      EVIDENCE_DIR="$2"
      shift 2
      ;;
    --binary)
      [[ $# -ge 2 && -z "$BINARY" ]] || usage_error "--binary requires one value and may appear once"
      BINARY="$2"
      shift 2
      ;;
    --app-bundle)
      [[ $# -ge 2 && -z "$APP_BUNDLE" ]] || usage_error "--app-bundle requires one value and may appear once"
      APP_BUNDLE="$2"
      shift 2
      ;;
    --package-manifest-only)
      [[ "$PACKAGE_MANIFEST_ONLY" -eq 0 ]] || usage_error "--package-manifest-only may appear once"
      PACKAGE_MANIFEST_ONLY=1
      shift
      ;;
    *) usage_error "unknown option: $1" ;;
  esac
done

[[ -n "$REPO_ROOT" ]] || usage_error "--repo-root is required"

validate_repo_root() {
  [[ "$REPO_ROOT" == /* ]] || usage_error "--repo-root must be absolute"
  [[ -d "$REPO_ROOT" && ! -L "$REPO_ROOT" ]] || fail "repository root must be a regular directory, not a symlink"
  REPO_ROOT="$(cd -P "$REPO_ROOT" && pwd)"
}

verify_package_manifest() {
  command -v find >/dev/null 2>&1 || fail "required tool is unavailable: find"
  command -v shasum >/dev/null 2>&1 || fail "required tool is unavailable: shasum"
  command -v awk >/dev/null 2>&1 || fail "required tool is unavailable: awk"

  local primary_count=0
  local path=""
  local basename=""
  while IFS= read -r -d '' path; do
    basename="${path##*/}"
    case "$basename" in
      Package.swift)
        primary_count=$((primary_count + 1))
        [[ -f "$path" && ! -L "$path" ]] || fail "Package.swift must be one regular non-symlink file"
        ;;
      Package@swift-*.swift)
        fail "version-specific package manifest is forbidden"
        ;;
    esac
  done < <(find -P "$REPO_ROOT" -mindepth 1 -maxdepth 1 -print0)

  [[ "$primary_count" -eq 1 ]] || fail "Package.swift must be one regular non-symlink file"
  [[ ! -e "$REPO_ROOT/Package.resolved" && ! -L "$REPO_ROOT/Package.resolved" ]] || fail "Package.resolved is forbidden"

  local manifest="$REPO_ROOT/Package.swift"
  local before_hash
  before_hash="$(sha256 "$manifest")"
  [[ "$before_hash" == "$S0_PACKAGE_MANIFEST_SHA256" ]] || fail "Package.swift does not match the frozen declarative manifest"

  local swiftc
  swiftc="$(command -v swiftc || true)"
  [[ -n "$swiftc" ]] || fail "required tool is unavailable: swiftc"
  "$swiftc" -frontend -parse "$manifest" >/dev/null
  [[ "$(sha256 "$manifest")" == "$before_hash" ]] || fail "Package.swift changed during manifest verification"
}

validate_repo_root
if [[ "$PACKAGE_MANIFEST_ONLY" -eq 1 ]]; then
  [[ -z "$SCRATCH_PATH$CONFIGURATION$BUILD_DESCRIPTION$EVIDENCE_DIR$BINARY$APP_BUNDLE" ]] || usage_error "--package-manifest-only cannot be combined with full-verifier options"
  verify_package_manifest
  printf 'S0 package manifest policy: PASS\n'
  exit 0
fi

verify_package_manifest

[[ -n "$SCRATCH_PATH" ]] || usage_error "--scratch-path is required in full mode"
[[ -n "$CONFIGURATION" ]] || usage_error "--configuration is required in full mode"
[[ -n "$BUILD_DESCRIPTION" ]] || usage_error "--build-description is required in full mode"
[[ -n "$EVIDENCE_DIR" ]] || usage_error "--evidence-dir is required in full mode"
[[ -n "$BINARY" ]] || usage_error "--binary is required in full mode"
[[ "$CONFIGURATION" == "release" ]] || usage_error "--configuration must be release"

for required_tool in python3 swift nm xcrun strings otool shasum awk cmp find file; do
  command -v "$required_tool" >/dev/null 2>&1 || fail "required tool is unavailable: $required_tool"
done

validate_clean_absolute_path() {
  local option_name="$1"
  local value="$2"
  [[ "$value" == /* ]] || usage_error "$option_name must be absolute"
  python3 - "$option_name" "$value" <<'PY'
import sys
name, value = sys.argv[1:]
if any(ord(character) < 32 or ord(character) == 127 for character in value):
    raise SystemExit(f"S0 verification failed: {name} contains a control byte")
PY
}

validate_clean_absolute_path "--scratch-path" "$SCRATCH_PATH"
validate_clean_absolute_path "--build-description" "$BUILD_DESCRIPTION"
validate_clean_absolute_path "--evidence-dir" "$EVIDENCE_DIR"
validate_clean_absolute_path "--binary" "$BINARY"
[[ -z "$APP_BUNDLE" ]] || validate_clean_absolute_path "--app-bundle" "$APP_BUNDLE"

[[ -d "$SCRATCH_PATH" && ! -L "$SCRATCH_PATH" ]] || fail "scratch path must be a regular non-symlink directory"
[[ -d "$EVIDENCE_DIR" && ! -L "$EVIDENCE_DIR" ]] || fail "evidence directory must be a regular non-symlink directory"
[[ -f "$BUILD_DESCRIPTION" && ! -L "$BUILD_DESCRIPTION" ]] || fail "build description must be a regular non-symlink file"
[[ -f "$BINARY" && ! -L "$BINARY" ]] || fail "binary must be a regular non-symlink file"
[[ -z "$APP_BUNDLE" || ( -d "$APP_BUNDLE" && ! -L "$APP_BUNDLE" ) ]] || fail "app bundle must be a regular non-symlink directory"

SCRATCH_PATH="$(cd -P "$SCRATCH_PATH" && pwd)"
EVIDENCE_DIR="$(cd -P "$EVIDENCE_DIR" && pwd)"
BUILD_DESCRIPTION="$(cd -P "$(dirname "$BUILD_DESCRIPTION")" && pwd)/$(basename "$BUILD_DESCRIPTION")"
BINARY="$(cd -P "$(dirname "$BINARY")" && pwd)/$(basename "$BINARY")"
if [[ -n "$APP_BUNDLE" ]]; then
  APP_BUNDLE="$(cd -P "$APP_BUNDLE" && pwd)"
fi

case "$SCRATCH_PATH/" in "$REPO_ROOT/"*) fail "scratch path must be outside the repository" ;; esac
case "$EVIDENCE_DIR/" in "$REPO_ROOT/"*) fail "evidence directory must be outside the repository" ;; esac
case "$BUILD_DESCRIPTION" in "$SCRATCH_PATH/"*) ;; *) fail "build description must be inside the exact scratch" ;; esac
if [[ -z "$APP_BUNDLE" ]]; then
  case "$BINARY" in "$SCRATCH_PATH/"*) ;; *) fail "direct Release binary must be inside the exact scratch" ;; esac
else
  case "$BINARY" in "$APP_BUNDLE/Contents/MacOS/"*) ;; *) fail "bundle binary must be inside the exact app bundle" ;; esac
fi

expected_description="$(python3 - "$SCRATCH_PATH" <<'PY'
import os
import stat
import sys

scratch = os.path.realpath(sys.argv[1])
matches = []
for directory, dirnames, filenames in os.walk(scratch, topdown=True, followlinks=False):
    for name in list(dirnames):
        path = os.path.join(directory, name)
        if os.path.islink(path):
            # SwiftPM creates this one convenience link after a successful
            # build. It is never traversed; the physical target is verified.
            expected = os.path.join(scratch, "arm64-apple-macosx", "release")
            if directory != scratch or name != "release" or os.path.realpath(path) != expected:
                raise SystemExit("S0 verification failed: unexpected symlink found in Release scratch")
            dirnames.remove(name)
    for name in filenames:
        path = os.path.join(directory, name)
        if os.path.islink(path):
            continue
        relative = os.path.relpath(path, scratch).replace(os.sep, "/")
        if relative.endswith("/release/description.json") and stat.S_ISREG(os.lstat(path).st_mode):
            matches.append(os.path.realpath(path))
if len(matches) != 1:
    raise SystemExit(f"S0 verification failed: expected one Release description.json, found {len(matches)}")
print(matches[0])
PY
)"
[[ "$BUILD_DESCRIPTION" == "$expected_description" ]] || fail "build description is not the sole Release description in the exact scratch"

BUILT_BINARY="$(python3 - "$SCRATCH_PATH" <<'PY'
import os
import stat
import sys

scratch = os.path.realpath(sys.argv[1])
matches = []
for directory, dirnames, filenames in os.walk(scratch, topdown=True, followlinks=False):
    dirnames[:] = [name for name in dirnames if not os.path.islink(os.path.join(directory, name))]
    for name in filenames:
        path = os.path.join(directory, name)
        relative = os.path.relpath(path, scratch).replace(os.sep, "/")
        if relative.endswith("/release/MindDesk") and stat.S_ISREG(os.lstat(path).st_mode) and not os.path.islink(path):
            matches.append(os.path.realpath(path))
if len(matches) != 1:
    raise SystemExit(f"S0 verification failed: expected one built Release MindDesk binary, found {len(matches)}")
print(matches[0])
PY
)"
if [[ -z "$APP_BUNDLE" ]]; then
  [[ "$BINARY" == "$BUILT_BINARY" ]] || fail "--binary is not the exact direct Release output"
else
  [[ "$(sha256 "$BINARY")" == "$(sha256 "$BUILT_BINARY")" ]] || fail "bundle binary differs from the exact built Release output"
fi

evidence_state="$(python3 - "$EVIDENCE_DIR" <<'PY'
import os
import stat
import sys

root = sys.argv[1]
entries = sorted(os.listdir(root))
for name in entries:
    path = os.path.join(root, name)
    if os.path.islink(path) or not stat.S_ISREG(os.lstat(path).st_mode):
        raise SystemExit("S0 verification failed: unsafe entry in evidence directory")
allowed = ["normalized-build-plan.json", "source-policy-evidence.json"]
if not entries:
    print("initial")
elif entries == allowed:
    print("existing")
else:
    raise SystemExit("S0 verification failed: evidence directory must be initially empty or contain only canonical evidence")
PY
)"

description_hash_before="$(sha256 "$BUILD_DESCRIPTION")"
binary_hash_before="$(sha256 "$BINARY")"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/minddesk-s0-verify.XXXXXX")"
cleanup_work_dir() {
  case "$WORK_DIR" in
    "${TMPDIR:-/tmp}"/minddesk-s0-verify.??????)
      [[ -d "$WORK_DIR" && ! -L "$WORK_DIR" ]] && rm -rf -- "$WORK_DIR"
      ;;
    *) return 1 ;;
  esac
}
trap cleanup_work_dir EXIT

swift package --package-path "$REPO_ROOT" --scratch-path "$SCRATCH_PATH" show-dependencies --format json >"$WORK_DIR/dependencies.json"
swift package --package-path "$REPO_ROOT" --scratch-path "$SCRATCH_PATH" describe --type json >"$WORK_DIR/package-description.json"

s0_policy_check_source_tree "$REPO_ROOT"

python3 - \
  "$REPO_ROOT" \
  "$SCRATCH_PATH" \
  "$BUILD_DESCRIPTION" \
  "$WORK_DIR/dependencies.json" \
  "$WORK_DIR/package-description.json" \
  "$BUILT_BINARY" \
  "$description_hash_before" \
  "$S0_PACKAGE_MANIFEST_SHA256" \
  "$S0_RESOURCE_ACCESSOR_NORMALIZED_SHA256S" \
  "$WORK_DIR/normalized-build-plan.json" \
  "$WORK_DIR/source-policy-evidence.json" <<'PY'
import hashlib
import json
import os
import stat
import sys

(
    repo,
    scratch,
    build_description_path,
    dependencies_path,
    package_description_path,
    binary_path,
    build_description_hash,
    manifest_hash,
    expected_generated_hashes,
    normalized_output,
    policy_output,
) = sys.argv[1:]
repo = os.path.realpath(repo)
scratch_argument = scratch
scratch = os.path.realpath(scratch)
expected_generated_hashes = set(expected_generated_hashes.split())

def load_strict(path):
    def pairs(values):
        result = {}
        for key, value in values:
            if key in result:
                raise ValueError(f"duplicate JSON key: {key}")
            result[key] = value
        return result
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle, object_pairs_hook=pairs)

def sha(path, replacement=None):
    data = open(path, "rb").read()
    if replacement is not None:
        prefixes = {scratch_argument, scratch}
        if scratch.startswith("/private/tmp/"):
            prefixes.add(scratch[len("/private"):])
        if scratch_argument.startswith("/private/tmp/"):
            prefixes.add(scratch_argument[len("/private"):])
        for prefix in prefixes:
            data = data.replace(prefix.encode(), replacement.encode())
    return hashlib.sha256(data).hexdigest()

def relative_to(path, root):
    real = os.path.realpath(path)
    try:
        common = os.path.commonpath([real, root])
    except ValueError:
        return None
    if common != root:
        return None
    return os.path.relpath(real, root).replace(os.sep, "/")

dependencies = load_strict(dependencies_path)
if not isinstance(dependencies, dict) or dependencies.get("name") != "MindDesk":
    raise SystemExit("S0 verification failed: dependency JSON does not describe MindDesk")
if dependencies.get("dependencies") != []:
    raise SystemExit("S0 verification failed: external package dependency is present")
if os.path.realpath(str(dependencies.get("path", ""))) != repo:
    raise SystemExit("S0 verification failed: dependency JSON root path mismatch")

package = load_strict(package_description_path)
if not isinstance(package, dict) or package.get("name") != "MindDesk" or package.get("dependencies") != []:
    raise SystemExit("S0 verification failed: package description has an unexpected identity or dependency")
if package.get("tools_version") != "6.0":
    raise SystemExit("S0 verification failed: unexpected Swift tools version")
products = {(item.get("name"), next(iter(item.get("type", {})), "")) for item in package.get("products", []) if isinstance(item, dict)}
if products != {("MindDesk", "executable"), ("MindDeskCore", "library")}:
    raise SystemExit("S0 verification failed: unexpected production product set")

description = load_strict(build_description_path)
commands = description.get("swiftCommands")
if not isinstance(commands, dict) or not commands:
    raise SystemExit("S0 verification failed: build description has no Swift commands")
production_commands = {}
allowed_plan_modules = {"MindDesk", "MindDeskCore", "MindDeskCoreTests", "MindDeskTests", "MindDeskPackageTests"}
for command in commands.values():
    if not isinstance(command, dict):
        raise SystemExit("S0 verification failed: malformed Swift command")
    module = command.get("moduleName")
    if module in {"MindDesk", "MindDeskCore"}:
        if module in production_commands:
            raise SystemExit("S0 verification failed: duplicate production module command")
        production_commands[module] = command
    elif module not in allowed_plan_modules:
        raise SystemExit(f"S0 verification failed: unexpected Release module command {module!r}")
if set(production_commands) != {"MindDesk", "MindDeskCore"}:
    raise SystemExit("S0 verification failed: incomplete production module command set")
if description.get("swiftFrontendCommands") not in ({}, None):
    raise SystemExit("S0 verification failed: unexpected standalone frontend command")

repository_sources = []
for relative_root in ("Sources/MindDesk", "Sources/MindDeskCore"):
    absolute_root = os.path.join(repo, relative_root)
    for directory, dirnames, filenames in os.walk(absolute_root, topdown=True, followlinks=False):
        if any(os.path.islink(os.path.join(directory, name)) for name in dirnames):
            raise SystemExit("S0 verification failed: symlink in source tree")
        for name in filenames:
            path = os.path.join(directory, name)
            if name.endswith(".swift"):
                if os.path.islink(path) or not stat.S_ISREG(os.lstat(path).st_mode):
                    raise SystemExit("S0 verification failed: unsafe Swift source")
                repository_sources.append(os.path.realpath(path))
repository_sources = sorted(repository_sources)

recorded_repository_sources = []
generated_sources = []
modules = []
for module in sorted(production_commands):
    command = production_commands[module]
    if command.get("wholeModuleOptimization") is not True:
        raise SystemExit("S0 verification failed: Release command lacks whole-module optimization")
    executable = command.get("executable")
    if not isinstance(executable, str) or not os.path.isabs(executable) or not os.path.isfile(executable):
        raise SystemExit("S0 verification failed: invalid Swift compiler executable")
    module_sources = []
    for source in command.get("sources", []):
        if not isinstance(source, str) or not os.path.isabs(source):
            raise SystemExit("S0 verification failed: invalid source path in build description")
        repo_relative = relative_to(source, repo)
        scratch_relative = relative_to(source, scratch)
        if repo_relative is not None and (repo_relative.startswith("Sources/MindDesk/") or repo_relative.startswith("Sources/MindDeskCore/")):
            recorded_repository_sources.append(os.path.realpath(source))
            module_sources.append({"path": repo_relative, "sha256": sha(source)})
        elif scratch_relative is not None and scratch_relative.endswith("/release/MindDesk.build/DerivedSources/resource_bundle_accessor.swift"):
            normalized_hash = sha(source, "${SCRATCH}")
            if normalized_hash not in expected_generated_hashes:
                raise SystemExit(
                    "S0 verification failed: generated resource accessor does not match an approved toolchain template "
                    f"(normalized SHA-256: {normalized_hash})"
                )
            generated_sources.append({"path": "${SCRATCH}/" + scratch_relative, "normalizedSha256": normalized_hash})
            module_sources.append({"path": "${SCRATCH}/" + scratch_relative, "normalizedSha256": normalized_hash})
        else:
            raise SystemExit(f"S0 verification failed: unknown production source path {source!r}")
    for key in ("objects",):
        for path in command.get(key, []):
            if relative_to(path, scratch) is None:
                raise SystemExit("S0 verification failed: production object is outside exact scratch")
    for key in ("fileList", "importPath", "moduleOutputPath", "outputFileMapPath", "tempsPath"):
        path = command.get(key)
        if not isinstance(path, str) or relative_to(path, scratch) is None:
            raise SystemExit(f"S0 verification failed: {key} is outside exact scratch")
    for output in command.get("outputs", []):
        if not isinstance(output, dict) or relative_to(str(output.get("name", "")), scratch) is None:
            raise SystemExit("S0 verification failed: production output is outside exact scratch")
    modules.append({"name": module, "isLibrary": bool(command.get("isLibrary")), "sources": sorted(module_sources, key=lambda item: item["path"])})

if sorted(set(recorded_repository_sources)) != repository_sources:
    raise SystemExit("S0 verification failed: build description source set differs from production tree")
if len(generated_sources) != 1:
    raise SystemExit("S0 verification failed: expected one frozen generated source")
binary_relative = relative_to(binary_path, scratch)
if binary_relative is None or not binary_relative.endswith("/release/MindDesk"):
    raise SystemExit("S0 verification failed: binary is not the expected Release MindDesk output")

source_records = [{"path": os.path.relpath(path, repo).replace(os.sep, "/"), "sha256": sha(path)} for path in repository_sources]
normalized = {
    "schema": 1,
    "configuration": "release",
    "package": {"name": "MindDesk", "externalDependencies": []},
    "products": ["MindDesk", "MindDeskCore"],
    "buildDescriptionSha256": build_description_hash,
    "modules": modules,
}
policy = {
    "schema": 1,
    "policySchema": 1,
    "manifestSha256": manifest_hash,
    "approvedRoots": ["Sources/MindDesk", "Sources/MindDeskCore"],
    "sourceFiles": source_records,
    "generatedSources": sorted(generated_sources, key=lambda item: item["path"]),
}
for path, value in ((normalized_output, normalized), (policy_output, policy)):
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, ensure_ascii=True, sort_keys=True, separators=(",", ":"))
        handle.write("\n")
PY

file "$BINARY" | grep -Fq 'Mach-O' || fail "binary is not a Mach-O code object"
demangler="$(xcrun --find swift-demangle)"
[[ -x "$demangler" ]] || fail "Swift demangler is unavailable"
nm -a "$BINARY" | "$demangler" >"$WORK_DIR/demangled-symbols.txt"
for stem in "${S0_DENIED_SYMBOL_STEMS[@]}"; do
  if grep -Fq "$stem" "$WORK_DIR/demangled-symbols.txt"; then
    fail "forbidden runtime symbol stem is present: $stem"
  fi
done

otool -L "$BINARY" >"$WORK_DIR/dependencies.txt"
python3 - "$WORK_DIR/dependencies.txt" <<'PY'
import sys
lines = open(sys.argv[1], encoding="utf-8", errors="strict").read().splitlines()[1:]
for line in lines:
    path = line.strip().split(" (", 1)[0]
    if path and not path.startswith(("/System/Library/", "/usr/lib/", "@rpath/")):
        raise SystemExit(f"S0 verification failed: unexpected binary dependency {path!r}")
PY

scan_artifact_strings() {
  local artifact="$1"
  local label="$2"
  strings -a "$artifact" >"$WORK_DIR/strings.txt"
  local marker
  for marker in "${S0_DENIED_ARTIFACT_STRINGS[@]}"; do
    if grep -Fq "$marker" "$WORK_DIR/strings.txt"; then
      fail "forbidden runtime string in $label: $marker"
    fi
  done
}

scan_artifact_strings "$BINARY" "MindDesk binary"

if [[ -n "$APP_BUNDLE" ]]; then
  python3 - "$APP_BUNDLE" "$BINARY" <<'PY'
import os
import plistlib
import stat
import sys

bundle = os.path.realpath(sys.argv[1])
binary = os.path.realpath(sys.argv[2])
contents = os.path.join(bundle, "Contents")
plist_path = os.path.join(contents, "Info.plist")
if not os.path.isfile(plist_path) or os.path.islink(plist_path):
    raise SystemExit("S0 verification failed: bundle Info.plist is missing or unsafe")
with open(plist_path, "rb") as handle:
    plist = plistlib.load(handle)
executable = plist.get("CFBundleExecutable")
if executable != "MindDesk":
    raise SystemExit("S0 verification failed: unexpected CFBundleExecutable")
expected_binary = os.path.join(contents, "MacOS", executable)
if not os.path.isfile(expected_binary) or os.path.islink(expected_binary) or not os.path.samefile(expected_binary, binary):
    raise SystemExit("S0 verification failed: --binary is not the bundle's sole main executable")

macos_files = []
code_roots = {"Frameworks", "PlugIns", "XPCServices", "Helpers", "Library"}
for directory, dirnames, filenames in os.walk(contents, topdown=True, followlinks=False):
    for name in dirnames:
        path = os.path.join(directory, name)
        if os.path.islink(path):
            raise SystemExit("S0 verification failed: symlink in app bundle")
    for name in filenames:
        path = os.path.join(directory, name)
        relative = os.path.relpath(path, contents).replace(os.sep, "/")
        mode = os.lstat(path).st_mode
        if os.path.islink(path) or not stat.S_ISREG(mode):
            raise SystemExit("S0 verification failed: unsafe file type in app bundle")
        first = relative.split("/", 1)[0]
        if first == "MacOS":
            macos_files.append(os.path.realpath(path))
        elif first in code_roots:
            raise SystemExit(f"S0 verification failed: extra bundled code location {relative}")
        elif mode & 0o111:
            raise SystemExit(f"S0 verification failed: executable resource in app bundle: {relative}")
        else:
            magic = open(path, "rb").read(4)
            if magic in {b"\xfe\xed\xfa\xce", b"\xce\xfa\xed\xfe", b"\xfe\xed\xfa\xcf", b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca"}:
                raise SystemExit(f"S0 verification failed: hidden Mach-O resource in app bundle: {relative}")
if macos_files != [binary]:
    raise SystemExit("S0 verification failed: app bundle must contain exactly one MacOS code object")
PY
  while IFS= read -r -d '' bundle_file; do
    [[ "$(cd -P "$(dirname "$bundle_file")" && pwd)/$(basename "$bundle_file")" == "$BINARY" ]] && continue
    scan_artifact_strings "$bundle_file" "app bundle resource"
  done < <(find -P "$APP_BUNDLE/Contents" -type f -print0)
fi

[[ "$(sha256 "$BUILD_DESCRIPTION")" == "$description_hash_before" ]] || fail "build description changed during verification"
[[ "$(sha256 "$BINARY")" == "$binary_hash_before" ]] || fail "binary changed during verification"
s0_policy_check_source_tree "$REPO_ROOT"

install_or_compare_evidence() {
  local generated="$1"
  local name="$2"
  local destination="$EVIDENCE_DIR/$name"
  if [[ "$evidence_state" == "existing" ]]; then
    cmp -s "$generated" "$destination" || fail "canonical evidence changed: $name"
  else
    local temporary="$EVIDENCE_DIR/.${name}.tmp.$$"
    [[ ! -e "$temporary" && ! -L "$temporary" ]] || fail "temporary evidence path already exists"
    cp "$generated" "$temporary"
    chmod 0600 "$temporary"
    mv "$temporary" "$destination"
  fi
}

install_or_compare_evidence "$WORK_DIR/normalized-build-plan.json" "normalized-build-plan.json"
install_or_compare_evidence "$WORK_DIR/source-policy-evidence.json" "source-policy-evidence.json"

cleanup_work_dir
trap - EXIT
printf 'S0 private Canvas Release policy: PASS\n'
