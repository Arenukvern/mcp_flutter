#!/usr/bin/env bash
# Smoke-check release tarball matches declared triple (linux-x64 / darwin-arm64).
set -euo pipefail

fail() { echo "verify_release_tarball_architecture: $*" >&2; exit 1; }
ok() { echo "verify_release_tarball_architecture: $*"; }

ARCHIVE="${1:-}"
TRIPLE="${2:-}"

[[ -f "$ARCHIVE" && -n "$TRIPLE" ]] || fail "usage: verify_release_tarball_architecture.sh <archive.tar.gz> <triple>"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

tar -C "$tmpdir" -xzf "$ARCHIVE"
mapfile -d '' bins < <(find "$tmpdir" -type f \( -name flutter-mcp-toolkit -o -name flutter-mcp-toolkit-server \) -print0)
[[ ${#bins[@]} -ge 2 ]] || fail "expected toolkit + server binaries in $ARCHIVE"

file_out="$(file "${bins[0]}")"

case "$TRIPLE" in
  linux-x64)
    echo "$file_out" | grep -qE 'ELF 64-bit.*x86-64' || fail "not linux x86-64: $file_out"
    ;;
  darwin-arm64)
    echo "$file_out" | grep -qE 'Mach-O.*arm64' || fail "not darwin arm64: $file_out"
    ;;
  *)
    fail "unsupported triple: $TRIPLE"
    ;;
esac

ok "$ARCHIVE ($TRIPLE)"
