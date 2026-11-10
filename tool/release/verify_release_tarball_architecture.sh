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
# bash 3.2 compatible — macOS runners ship bash 3.2 (no mapfile).
bins=()
while IFS= read -r -d '' bin; do
  bins+=("$bin")
done < <(find "$tmpdir" -type f \( -name flutter-mcp-toolkit -o -name flutter-mcp-toolkit-server \) -print0 | sort -z)
[[ ${#bins[@]} -ge 2 ]] || fail "expected toolkit + server binaries in $ARCHIVE"

verify_one() {
  local bin="$1"
  local file_out
  file_out="$(file "$bin")"
  case "$TRIPLE" in
    linux-x64)
      echo "$file_out" | grep -qE 'ELF 64-bit.*x86-64' || fail "not linux x86-64: $bin → $file_out"
      ;;
    darwin-arm64)
      echo "$file_out" | grep -qE 'Mach-O.*arm64' || fail "not darwin arm64: $bin → $file_out"
      ;;
    *)
      fail "unsupported triple: $TRIPLE"
      ;;
  esac
}

for bin in "${bins[@]}"; do
  verify_one "$bin"
done

ok "$ARCHIVE ($TRIPLE) — ${#bins[@]} binaries verified"
