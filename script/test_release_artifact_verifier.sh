#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERIFIER="$ROOT_DIR/script/verify_release_artifacts.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/minddesk-artifact-verifier.XXXXXX")"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
HEAD_ID="0123456789abcdef0123456789abcdef01234567"
VERSION="1.2.3"
SUFFIX="macOS-test"
NAME="MindDesk-v$VERSION-$SUFFIX-adhoc"

fail() { echo "$1" >&2; exit 1; }
verify() { bash "$VERIFIER" --artifact-dir "$1" --source-head "$HEAD_ID" --version "$VERSION" --suffix "$SUFFIX" --mode adhoc; }
assert_fails() {
  local expected="$1" directory="$2" output
  if output="$(verify "$directory" 2>&1)"; then fail "Expected artifact verifier failure: $expected"; fi
  grep -Fq "$expected" <<<"$output" || { printf '%s\n' "$output" >&2; fail "Missing failure: $expected"; }
}

make_fixture() {
  local directory="$1"
  mkdir -p "$directory"
  python3 - "$directory" "$HEAD_ID" "$VERSION" "$SUFFIX" "$NAME" <<'PY'
import hashlib,json,os,sys
root,head,version,suffix,name=sys.argv[1:]
def write(name,data): open(os.path.join(root,name),"wb").write(data)
def sha(name): return hashlib.sha256(open(os.path.join(root,name),"rb").read()).hexdigest()
manifest={"schemaVersion":1,"entries":[{"relativePath":"Contents","type":"directory","mode":"0755"},{"relativePath":"Contents/Info.plist","type":"file","mode":"0644","size":5,"sha256":hashlib.sha256(b"plist").hexdigest()}]}
for path in ("pre-sign.bundle.manifest.json","final-app.bundle.manifest.json"):
    write(path,(json.dumps(manifest,sort_keys=True,separators=(",",":"))+"\n").encode())
write(f"{name}.zip",b"zip\n"); write(f"{name}.dmg",b"dmg\n")
write("normalized-build-plan.json",b'{"schema":1}\n'); write("source-policy-evidence.json",b'{"schema":1}\n')
same="a"*64
provenance={"schemaVersion":1,"sourceHead":head,"configuration":"release","buildDescriptionSha256":"b"*64,
"normalizedBuildPlanSha256":sha("normalized-build-plan.json"),"sourcePolicyEvidenceSha256":sha("source-policy-evidence.json"),
"scratchBinarySha256":same,"unsignedBundleBinarySha256":same,"preSignBundleManifestSha256":sha("pre-sign.bundle.manifest.json")}
write("build-provenance.json",(json.dumps(provenance,sort_keys=True,separators=(",",":"))+"\n").encode())
artifacts=[("zip",f"{name}.zip"),("dmg",f"{name}.dmg")]
proofs=[("build-provenance","build-provenance.json"),("normalized-build-plan","normalized-build-plan.json"),("source-policy-evidence","source-policy-evidence.json"),("pre-sign-bundle-manifest","pre-sign.bundle.manifest.json"),("final-app-bundle-manifest","final-app.bundle.manifest.json")]
document={"schemaVersion":1,"sourceHead":head,"version":version,"suffix":suffix,"mode":"adhoc",
"artifacts":[{"kind":kind,"relativePath":path,"sha256":sha(path)} for kind,path in artifacts],
"proofs":[{"kind":kind,"relativePath":path,"sha256":sha(path)} for kind,path in proofs]}
write("verified-artifacts.json",(json.dumps(document,sort_keys=True,separators=(",",":"))+"\n").encode())
with open(os.path.join(root,"SHA256SUMS.txt"),"w",encoding="ascii",newline="\n") as handle:
    for entry in sorted(document["artifacts"]+document["proofs"],key=lambda item:item["relativePath"]): handle.write(f'{entry["sha256"]}  {entry["relativePath"]}\n')
PY
}

valid="$TMP_ROOT/valid"; make_fixture "$valid"; verify "$valid" >/dev/null

tampered="$TMP_ROOT/tampered"; cp -R "$valid" "$tampered"; printf 'changed\n' >>"$tampered/$NAME.zip"
assert_fails "SHA-256 mismatch for zip" "$tampered"

duplicate="$TMP_ROOT/duplicate"; cp -R "$valid" "$duplicate"
python3 - "$duplicate/verified-artifacts.json" <<'PY'
import sys
path=sys.argv[1]; data=open(path).read(); open(path,"w").write(data.replace('{"artifacts":','{"schemaVersion":1,"artifacts":',1))
PY
assert_fails "duplicate JSON key" "$duplicate"

escaping="$TMP_ROOT/escaping"; cp -R "$valid" "$escaping"
python3 - "$escaping/verified-artifacts.json" <<'PY'
import json,sys
path=sys.argv[1]; value=json.load(open(path)); value["artifacts"][0]["relativePath"]="../escape.zip"; json.dump(value,open(path,"w"),sort_keys=True,separators=(",",":"))
PY
assert_fails "wrong relativePath for zip" "$escaping"

wrong_head="$TMP_ROOT/wrong-head"; cp -R "$valid" "$wrong_head"
python3 - "$wrong_head/verified-artifacts.json" <<'PY'
import json,sys
path=sys.argv[1]; value=json.load(open(path)); value["sourceHead"]="f"*40; json.dump(value,open(path,"w"),sort_keys=True,separators=(",",":"))
PY
assert_fails "sourceHead mismatch" "$wrong_head"

self_hash="$TMP_ROOT/self-hash"; cp -R "$valid" "$self_hash"; printf '%064d  verified-artifacts.json\n' 0 >>"$self_hash/SHA256SUMS.txt"
assert_fails "does not exactly cover" "$self_hash"

symlink="$TMP_ROOT/symlink"; cp -R "$valid" "$symlink"; rm "$symlink/normalized-build-plan.json"; ln -s /dev/null "$symlink/normalized-build-plan.json"
assert_fails "not a regular non-symlink" "$symlink"

set +e
bash "$VERIFIER" --unknown >/dev/null 2>&1
status=$?
set -e
[[ "$status" -eq 2 ]] || fail "Expected usage status 2"
echo "Release artifact verifier tests passed."
