#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APPLY="$ROOT_DIR/tool/ci/apply_oka_consumer_overrides.sh"
PIN_FILE="$ROOT_DIR/tool/ci/oka_consumer_pin.txt"

fail() { echo "test_oka_consumer_overrides_guard: $*" >&2; exit 1; }
ok() { echo "test_oka_consumer_overrides_guard: $*"; }

[[ -x "$APPLY" ]] || APPLY="$ROOT_DIR/tool/ci/apply_oka_consumer_overrides.sh"
[[ -f "$APPLY" ]] || fail "missing apply_oka_consumer_overrides.sh"
grep -q 'GENERATED: oka consumer' "$APPLY" || fail "apply script must tag GENERATED overrides"
grep -q 'OKA_CONSUMER_OVERWRITE_OVERRIDES' "$APPLY" || fail "apply script must document overwrite opt-in"
grep -q 'fail_personal_override\|refusing to touch' "$APPLY" || fail "apply script must refuse personal root overrides"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

fake_root="$tmpdir/fake_repo"
mkdir -p "$fake_root/tool/ci" "$fake_root/oka/packages/oka_android"
echo testpin >"$fake_root/tool/ci/oka_consumer_pin.txt"
touch "$fake_root/oka/packages/oka_android/pubspec.yaml"
cp "$APPLY" "$fake_root/tool/ci/apply_oka_consumer_overrides.sh"

# Personal root override — must fail even with opt-in.
cat >"$fake_root/pubspec_overrides.yaml" <<'YAML'
dependency_overrides:
  some_sibling:
    path: ../elsewhere
YAML
if (cd "$fake_root" && OKA_CONSUMER_OVERWRITE_OVERRIDES=1 bash tool/ci/apply_oka_consumer_overrides.sh) 2>"$tmpdir/err"; then
  fail "must not overwrite personal root pubspec_overrides.yaml"
fi
grep -q 'refusing to touch' "$tmpdir/err" || fail "expected refuse message: $(cat "$tmpdir/err")"
ok "blocks personal root pubspec_overrides.yaml"

# Stale oka GENERATED without opt-in — must fail.
cat >"$fake_root/pubspec_overrides.yaml" <<'YAML'
# GENERATED: oka consumer test pin deadbeef
dependency_overrides: {}
YAML
if (cd "$fake_root" && bash tool/ci/apply_oka_consumer_overrides.sh) 2>"$tmpdir/err2"; then
  fail "must not overwrite GENERATED override without opt-in"
fi
grep -q 'overwrite not allowed' "$tmpdir/err2" || fail "expected overwrite guard: $(cat "$tmpdir/err2")"
ok "blocks GENERATED overwrite without opt-in"

# With opt-in — may replace GENERATED root file.
if ! (cd "$fake_root" && OKA_CONSUMER_OVERWRITE_OVERRIDES=1 bash tool/ci/apply_oka_consumer_overrides.sh); then
  fail "opt-in should write GENERATED root override"
fi
head -n 1 "$fake_root/pubspec_overrides.yaml" | grep -q '^# GENERATED: oka consumer' \
  || fail "written file must be GENERATED"
ok "opt-in writes GENERATED root override"

# Non-GENERATED member override — must not delete.
mkdir -p "$fake_root/packages/harness"
cat >"$fake_root/packages/harness/pubspec_overrides.yaml" <<'YAML'
dependency_overrides:
  local_pkg:
    path: ../../local
YAML
if ! (cd "$fake_root" && OKA_CONSUMER_OVERWRITE_OVERRIDES=1 bash tool/ci/apply_oka_consumer_overrides.sh); then
  fail "apply should succeed when harness override is personal"
fi
[[ -f "$fake_root/packages/harness/pubspec_overrides.yaml" ]] \
  || fail "must not delete non-GENERATED harness pubspec_overrides.yaml"
ok "preserves non-GENERATED member overrides"

ok "oka consumer override guard contract OK"
