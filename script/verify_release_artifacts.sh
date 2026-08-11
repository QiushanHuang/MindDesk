#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_DIR=""
SOURCE_HEAD=""
VERSION=""
SUFFIX=""
MODE=""

usage() {
  cat <<'USAGE'
Usage: verify_release_artifacts.sh --artifact-dir DIR --source-head HEAD \
  --version VERSION --suffix SUFFIX --mode adhoc|notarized

Validates the strict two-payload/five-proof private Canvas release identity chain.
USAGE
}

usage_error() {
  printf '%s\n' "$1" >&2
  usage >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-dir) [[ $# -ge 2 && -z "$ARTIFACT_DIR" ]] || usage_error "--artifact-dir requires one value"; ARTIFACT_DIR="$2"; shift 2 ;;
    --source-head) [[ $# -ge 2 && -z "$SOURCE_HEAD" ]] || usage_error "--source-head requires one value"; SOURCE_HEAD="$2"; shift 2 ;;
    --version) [[ $# -ge 2 && -z "$VERSION" ]] || usage_error "--version requires one value"; VERSION="$2"; shift 2 ;;
    --suffix) [[ $# -ge 2 && -z "$SUFFIX" ]] || usage_error "--suffix requires one value"; SUFFIX="$2"; shift 2 ;;
    --mode) [[ $# -ge 2 && -z "$MODE" ]] || usage_error "--mode requires one value"; MODE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage_error "unknown option: $1" ;;
  esac
done

[[ -n "$ARTIFACT_DIR" ]] || usage_error "--artifact-dir is required"
[[ "$SOURCE_HEAD" =~ ^[0-9a-f]{40,64}$ ]] || usage_error "--source-head must be a full lowercase hexadecimal commit id"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || usage_error "--version must be semantic x.y.z"
[[ "$SUFFIX" =~ ^[A-Za-z0-9._-]+$ ]] || usage_error "--suffix contains an unsafe character"
[[ "$MODE" == "adhoc" || "$MODE" == "notarized" ]] || usage_error "--mode must be adhoc or notarized"
command -v python3 >/dev/null 2>&1 || { echo "required tool unavailable: python3" >&2; exit 1; }

python3 - "$ARTIFACT_DIR" "$SOURCE_HEAD" "$VERSION" "$SUFFIX" "$MODE" <<'PY'
import hashlib
import json
import os
import re
import stat
import sys

artifact_dir, source_head, version, suffix, mode = sys.argv[1:]
artifact_dir = os.path.abspath(artifact_dir)

def fail(message):
    raise SystemExit(f"Release artifact verification failed: {message}")

def strict_load(path):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                fail(f"duplicate JSON key {key!r} in {os.path.basename(path)}")
            result[key] = value
        return result
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle, object_pairs_hook=pairs)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        fail(f"invalid JSON {os.path.basename(path)}: {error}")

def sha(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def regular(relative):
    if not isinstance(relative, str) or not relative or relative.startswith("/"):
        fail("proof path must be a non-empty relative path")
    if "\\" in relative or any(part in ("", ".", "..") for part in relative.split("/")):
        fail(f"unsafe proof path: {relative!r}")
    path = os.path.join(artifact_dir, relative)
    try:
        info = os.lstat(path)
    except OSError:
        fail(f"missing artifact or proof: {relative}")
    if not stat.S_ISREG(info.st_mode) or os.path.islink(path):
        fail(f"artifact or proof is not a regular non-symlink file: {relative}")
    if os.path.commonpath((os.path.realpath(path), os.path.realpath(artifact_dir))) != os.path.realpath(artifact_dir):
        fail(f"artifact or proof escapes artifact directory: {relative}")
    return path

if not os.path.isdir(artifact_dir) or os.path.islink(artifact_dir):
    fail("artifact directory is missing or is a symlink")

release_name = f"MindDesk-v{version}-{suffix}" + ("-adhoc" if mode == "adhoc" else "")
verified_path = regular("verified-artifacts.json")
checksums_path = regular("SHA256SUMS.txt")
document = strict_load(verified_path)
top_keys = {"schemaVersion", "sourceHead", "version", "suffix", "mode", "artifacts", "proofs"}
if not isinstance(document, dict) or set(document) != top_keys:
    fail("verified-artifacts.json has wrong top-level keys")
if type(document["schemaVersion"]) is not int or document["schemaVersion"] != 1:
    fail("schemaVersion must be integer 1")
for key, expected in (("sourceHead", source_head), ("version", version), ("suffix", suffix), ("mode", mode)):
    if type(document[key]) is not str or document[key] != expected:
        fail(f"verified-artifacts.json {key} mismatch")

expected = {
    "artifacts": {
        "zip": f"{release_name}.zip",
        "dmg": f"{release_name}.dmg",
    },
    "proofs": {
        "build-provenance": "build-provenance.json",
        "normalized-build-plan": "normalized-build-plan.json",
        "source-policy-evidence": "source-policy-evidence.json",
        "pre-sign-bundle-manifest": "pre-sign.bundle.manifest.json",
        "final-app-bundle-manifest": "final-app.bundle.manifest.json",
    },
}

records = []
for section in ("artifacts", "proofs"):
    value = document[section]
    if not isinstance(value, list) or len(value) != len(expected[section]):
        fail(f"{section} has wrong entry count")
    seen = set()
    for entry in value:
        if not isinstance(entry, dict) or set(entry) != {"kind", "relativePath", "sha256"}:
            fail(f"{section} entry has wrong keys")
        if any(type(entry[key]) is not str for key in entry):
            fail(f"{section} entry values must be strings")
        kind = entry["kind"]
        if kind in seen or kind not in expected[section]:
            fail(f"duplicate or unexpected {section} kind: {kind!r}")
        seen.add(kind)
        if entry["relativePath"] != expected[section][kind]:
            fail(f"wrong relativePath for {kind}")
        if re.fullmatch(r"[0-9a-f]{64}", entry["sha256"]) is None:
            fail(f"invalid lowercase SHA-256 for {kind}")
        path = regular(entry["relativePath"])
        if sha(path) != entry["sha256"]:
            fail(f"SHA-256 mismatch for {kind}")
        records.append((entry["relativePath"], entry["sha256"]))
    if seen != set(expected[section]):
        fail(f"missing {section} kind")

try:
    checksum_bytes = open(checksums_path, "rb").read()
    checksum_text = checksum_bytes.decode("ascii")
except (OSError, UnicodeError) as error:
    fail(f"invalid SHA256SUMS.txt: {error}")
expected_text = "".join(f"{digest}  {relative}\n" for relative, digest in sorted(records))
if checksum_text != expected_text:
    fail("SHA256SUMS.txt does not exactly cover the two payloads and five proofs")
if "verified-artifacts.json" in checksum_text or "SHA256SUMS.txt" in checksum_text:
    fail("identity files must not self-hash")

provenance = strict_load(regular("build-provenance.json"))
provenance_keys = {
    "schemaVersion", "sourceHead", "configuration", "buildDescriptionSha256",
    "normalizedBuildPlanSha256", "sourcePolicyEvidenceSha256",
    "scratchBinarySha256", "unsignedBundleBinarySha256",
    "preSignBundleManifestSha256",
}
if not isinstance(provenance, dict) or set(provenance) != provenance_keys:
    fail("build-provenance.json has wrong keys")
if type(provenance["schemaVersion"]) is not int or provenance["schemaVersion"] != 1:
    fail("build provenance schemaVersion must be integer 1")
if provenance["sourceHead"] != source_head or provenance["configuration"] != "release":
    fail("build provenance source/configuration mismatch")
for key in provenance_keys - {"schemaVersion", "sourceHead", "configuration"}:
    if not isinstance(provenance[key], str) or re.fullmatch(r"[0-9a-f]{64}", provenance[key]) is None:
        fail(f"invalid build provenance digest: {key}")
if provenance["scratchBinarySha256"] != provenance["unsignedBundleBinarySha256"]:
    fail("scratch and unsigned bundle binary identities differ")
if provenance["normalizedBuildPlanSha256"] != sha(regular("normalized-build-plan.json")):
    fail("normalized plan disagrees with build provenance")
if provenance["sourcePolicyEvidenceSha256"] != sha(regular("source-policy-evidence.json")):
    fail("source policy evidence disagrees with build provenance")
if provenance["preSignBundleManifestSha256"] != sha(regular("pre-sign.bundle.manifest.json")):
    fail("pre-sign manifest disagrees with build provenance")

for manifest_name in ("pre-sign.bundle.manifest.json", "final-app.bundle.manifest.json"):
    manifest = strict_load(regular(manifest_name))
    if not isinstance(manifest, dict) or set(manifest) != {"schemaVersion", "entries"}:
        fail(f"{manifest_name} has wrong top-level keys")
    if type(manifest["schemaVersion"]) is not int or manifest["schemaVersion"] != 1 or not isinstance(manifest["entries"], list):
        fail(f"{manifest_name} has wrong schema")
    paths = []
    for entry in manifest["entries"]:
        if not isinstance(entry, dict) or set(entry) not in ({"relativePath", "type", "mode"}, {"relativePath", "type", "mode", "size", "sha256"}):
            fail(f"{manifest_name} contains a malformed entry")
        relative = entry.get("relativePath")
        if not isinstance(relative, str) or relative.startswith("/") or "\\" in relative or any(part in ("", ".", "..") for part in relative.split("/")):
            fail(f"{manifest_name} contains an unsafe path")
        if not isinstance(entry.get("mode"), str) or re.fullmatch(r"[0-7]{4}", entry["mode"]) is None:
            fail(f"{manifest_name} contains an invalid mode")
        if entry.get("type") == "directory":
            if set(entry) != {"relativePath", "type", "mode"}:
                fail(f"{manifest_name} directory records size or hash")
        elif entry.get("type") == "file":
            if set(entry) != {"relativePath", "type", "mode", "size", "sha256"} or type(entry["size"]) is not int or entry["size"] < 0 or re.fullmatch(r"[0-9a-f]{64}", str(entry["sha256"])) is None:
                fail(f"{manifest_name} file entry is invalid")
        else:
            fail(f"{manifest_name} contains an unknown file type")
        paths.append(relative)
    if paths != sorted(paths, key=lambda item: item.encode("utf-8")) or len(paths) != len(set(paths)):
        fail(f"{manifest_name} paths are not unique byte order")

print(f"Release artifacts ok: {artifact_dir}")
for relative, digest in sorted(records):
    print(f"{os.path.join(artifact_dir, relative)} {digest}")
print(f"{verified_path} {sha(verified_path)}")
print(f"{checksums_path} {sha(checksums_path)}")
PY
