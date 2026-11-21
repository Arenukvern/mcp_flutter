#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/tool/release/extract_package_release_notes.sh"

fail() { echo "test_extract_package_release_notes: $*" >&2; exit 1; }
ok() { echo "test_extract_package_release_notes: $*"; }

[[ -x "$SCRIPT" ]] || fail "missing or non-executable $SCRIPT"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/changelog.md" <<'EOF'
# Train

## 8.0.0

### Major Changes

- **cli:** Strict ports.
- **core:** Shared parser.

## 7.2.1
EOF

out="$(bash "$SCRIPT" 8.0.0 "$tmpdir/changelog.md")"
printf '%s\n' "$out" | grep -q 'Strict ports' || fail "expected Major Changes body"
printf '%s\n' "$out" | grep -q '### Major Changes' || fail "expected Major Changes heading in body"

legacy="$(mktemp)"
cat >"$legacy" <<'EOF'
## [7.2.1] - 2026-11-18

### Fixed

- legacy heading
EOF
out2="$(bash "$SCRIPT" 7.2.1 "$legacy")"
printf '%s\n' "$out2" | grep -q 'legacy heading' || fail "legacy bracket heading"

ok "extract_package_release_notes OK"