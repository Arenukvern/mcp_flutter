#!/usr/bin/env bash
# Fixture-driven contract for the fail-closed MCPB registry gate
# (tool/release/assert_mcp_registry_release_assets.sh).
#
# The positive fixture passes; every negative fixture must BLOCK publish with a
# nonzero exit:
#   - the .mcpb asset missing from the release
#   - a sha256 mismatch against checksums.txt
#   - the darwin bundle missing inside the archive
#   - the linux bundle missing inside the archive
#   - a bundle manifest version that differs from the release version
#   - the required binary paths present only with a suffix (.bak trick)
#   - checksums.txt not listing the bundle
#
# Fixtures are generated at test time (no opaque binary blobs checked in).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE="$ROOT_DIR/tool/release/assert_mcp_registry_release_assets.sh"
TAG="v8.0.0"
VERSION="8.0.0"

fail() { echo "test_mcpb_release_asset_gate: $*" >&2; exit 1; }
ok() { echo "test_mcpb_release_asset_gate: $*"; }

[[ -f "$GATE" ]] || fail "missing $GATE"
command -v python3 >/dev/null 2>&1 || fail "python3 required to build zip fixtures"

fixtures="$(mktemp -d)"
cleanup() { rm -rf "$fixtures"; }
trap cleanup EXIT

FIXTURES="$fixtures" VERSION="$VERSION" python3 - <<'PY' || fail "fixture build failed"
import json
import os
import zipfile

fixtures = os.environ["FIXTURES"]
version = os.environ["VERSION"]

manifest = {
    "manifest_version": "0.3",
    "name": "flutter-mcp-toolkit",
    "version": version,
    "description": "fixture",
    "author": {"name": "fixture"},
    "server": {"type": "binary", "entry_point": "server/darwin-arm64/flutter-mcp-toolkit-server"},
}


def write_bundle(dest, with_darwin=True, with_linux=True, manifest_version=None):
    entries = {}
    if with_darwin:
        entries["server/darwin-arm64/flutter-mcp-toolkit-server"] = b"#!/bin/sh\nexit 0\n"
    if with_linux:
        entries["server/linux-x64/flutter-mcp-toolkit-server"] = b"#!/bin/sh\nexit 0\n"
    doc = dict(manifest)
    if manifest_version:
        doc["version"] = manifest_version
    entries["manifest.json"] = json.dumps(doc).encode()
    os.makedirs(dest, exist_ok=True)
    with zipfile.ZipFile(os.path.join(dest, "flutter-mcp-toolkit.mcpb"), "w") as zf:
        for name, data in entries.items():
            zf.writestr(name, data)


def write_checksums(dest, lines):
    os.makedirs(dest, exist_ok=True)
    with open(os.path.join(dest, "checksums.txt"), "w") as fh:
        fh.write(lines)


write_bundle(os.path.join(fixtures, "positive"))

# positive fixture checksums
bundle = os.path.join(fixtures, "positive", "flutter-mcp-toolkit.mcpb")
import hashlib
sha = hashlib.sha256(open(bundle, "rb").read()).hexdigest()
write_checksums(os.path.join(fixtures, "positive"),
                f"aaaa  flutter_mcp_{version}_darwin-arm64.tar.gz\n{sha}  flutter-mcp-toolkit.mcpb\n")

os.makedirs(os.path.join(fixtures, "missing_mcpb"), exist_ok=True)
write_checksums(os.path.join(fixtures, "missing_mcpb"),
                f"aaaa  flutter_mcp_{version}_darwin-arm64.tar.gz\n{sha}  flutter-mcp-toolkit.mcpb\n")

write_bundle(os.path.join(fixtures, "sha_mismatch"))
write_checksums(os.path.join(fixtures, "sha_mismatch"),
                f"{'0' * 64}  flutter-mcp-toolkit.mcpb\n")

write_bundle(os.path.join(fixtures, "darwin_missing"), with_darwin=False)
import hashlib as _h
write_checksums(os.path.join(fixtures, "darwin_missing"),
                _h.sha256(open(os.path.join(fixtures, "darwin_missing", "flutter-mcp-toolkit.mcpb"), "rb").read()).hexdigest() + "  flutter-mcp-toolkit.mcpb\n")

write_bundle(os.path.join(fixtures, "linux_missing"), with_linux=False)
write_checksums(os.path.join(fixtures, "linux_missing"),
                _h.sha256(open(os.path.join(fixtures, "linux_missing", "flutter-mcp-toolkit.mcpb"), "rb").read()).hexdigest() + "  flutter-mcp-toolkit.mcpb\n")

write_bundle(os.path.join(fixtures, "wrong_version"), manifest_version="7.9.9")
write_checksums(os.path.join(fixtures, "wrong_version"),
                _h.sha256(open(os.path.join(fixtures, "wrong_version", "flutter-mcp-toolkit.mcpb"), "rb").read()).hexdigest() + "  flutter-mcp-toolkit.mcpb\n")

# suffix_trick: the required paths appear only with a .bak suffix — the exact
# entry-name gate must reject this incomplete bundle.
os.makedirs(os.path.join(fixtures, "suffix_trick"), exist_ok=True)
with zipfile.ZipFile(os.path.join(fixtures, "suffix_trick", "flutter-mcp-toolkit.mcpb"), "w") as zf:
    zf.writestr("server/darwin-arm64/flutter-mcp-toolkit-server.bak", b"stale\n")
    zf.writestr("server/linux-x64/flutter-mcp-toolkit-server.bak", b"stale\n")
    zf.writestr("manifest.json", json.dumps(manifest).encode())
write_checksums(os.path.join(fixtures, "suffix_trick"),
                _h.sha256(open(os.path.join(fixtures, "suffix_trick", "flutter-mcp-toolkit.mcpb"), "rb").read()).hexdigest() + "  flutter-mcp-toolkit.mcpb\n")

# positive bundle re-listed: unlisted_checksum holds a bundle but checksums.txt
# does not mention it
write_bundle(os.path.join(fixtures, "unlisted_checksum"))
write_checksums(os.path.join(fixtures, "unlisted_checksum"),
                f"aaaa  flutter_mcp_{version}_darwin-arm64.tar.gz\n")
PY

run_gate() {
  local dir="$1"
  bash "$GATE" --tag "$TAG" --version "$VERSION" --assets-dir "$dir" >/dev/null 2>&1
}

run_gate "$fixtures/positive" &&
  ok "positive fixture passed the gate" ||
  fail "positive fixture must pass the gate"

for case_name in missing_mcpb sha_mismatch darwin_missing linux_missing wrong_version suffix_trick unlisted_checksum; do
  if run_gate "$fixtures/$case_name"; then
    fail "negative fixture '$case_name' passed the gate — publish would not be blocked"
  else
    ok "negative fixture '$case_name' blocked publish (nonzero exit)"
  fi
done

ok "MCPB registry gate fixtures OK"
