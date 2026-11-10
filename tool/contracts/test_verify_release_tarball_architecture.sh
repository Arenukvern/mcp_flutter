#!/usr/bin/env bash
# Smoke-test verify_release_tarball_architecture.sh on linux-x64 ELF fixtures.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/tool/release/verify_release_tarball_architecture.sh"
FIXTURE="$ROOT_DIR/tool/contracts/fixtures/linux_x64_elf_stub"

fail() { echo "test_verify_release_tarball_architecture: $*" >&2; exit 1; }
ok() { echo "test_verify_release_tarball_architecture: $*"; }

[[ -x "$SCRIPT" ]] || fail "missing executable $SCRIPT"
[[ -f "$FIXTURE" ]] || fail "missing fixture $FIXTURE"
command -v file >/dev/null 2>&1 || fail "file(1) required"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

stage="$tmpdir/stage"
mkdir -p "$stage/bin"
cp "$FIXTURE" "$stage/bin/flutter-mcp-toolkit"
cp "$FIXTURE" "$stage/bin/flutter-mcp-toolkit-server"
archive="$tmpdir/flutter_mcp_test_linux-x64.tar.gz"
tar -C "$stage" -czf "$archive" .

bash "$SCRIPT" "$archive" linux-x64 || fail "linux-x64 verification failed"

ok "verify_release_tarball_architecture.sh smoke passed"
