#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB_MUT="$ROOT/mcp_server_dart/lib/src/_doc_links_mutation_fixture.dart"
STALE_PROBE="$ROOT/mcp_server_dart/lib/src/_doc_links_stale_allowlist_probe.dart"
ALLOWLIST="$ROOT/tool/contracts/check_docs_links_allowlist.json"
ALLOWLIST_BACKUP="$(mktemp)"
SKILL_DIR="$ROOT/plugin/skills/_doc_links_mutation_fixture"
SKILL_MD="$SKILL_DIR/SKILL.md"
SKILL_YAML="$SKILL_DIR/probe.yaml"
PLUGIN_PROBE_DIR="$ROOT/plugin/_doc_links_mutation_fixture"
PLUGIN_PROBE_MD="$PLUGIN_PROBE_DIR/walkdir_probe.md"

GONE="${ROOT}/docs/core/gone.mdx"
GONE="${GONE#"$ROOT/"}"
STALE_TARGET="docs/quickstart.mdx"
STALE_CITING="mcp_server_dart/lib/src/_doc_links_stale_allowlist_probe.dart"

cleanup() {
  rm -f "$LIB_MUT" "$STALE_PROBE"
  rm -rf "$SKILL_DIR" "$PLUGIN_PROBE_DIR"
  cp "$ALLOWLIST_BACKUP" "$ALLOWLIST"
  rm -f "$ALLOWLIST_BACKUP"
}
trap cleanup EXIT

fail() {
  echo "test_docs_links_fixtures: $*" >&2
  exit 1
}

run_checker_must_match() {
  local needle="$1"
  local out
  out="$(mktemp)"
  set +e
  dart run tool/contracts/check_docs_links.dart 2>"$out" >/dev/null
  local ec=$?
  set -e
  if ((ec == 0)); then
    rm -f "$out"
    fail "checker must fail; expected stderr line: $needle"
  fi
  if ! grep -Fq "$needle" "$out"; then
    echo "--- checker stderr ---" >&2
    cat "$out" >&2
    rm -f "$out"
    fail "stderr missing expected line: $needle"
  fi
  rm -f "$out"
}

cp "$ALLOWLIST" "$ALLOWLIST_BACKUP"

cd "$ROOT"
if ! dart run tool/contracts/check_docs_links.dart; then
  fail "clean tree must pass"
fi

EXPECT_LIB="mcp_server_dart/lib/src/_doc_links_mutation_fixture.dart: broken doc path in source -> docs/core/gone.mdx"
EXPECT_SKILL_LINK="plugin/skills/_doc_links_mutation_fixture/SKILL.md: broken link -> ../../../docs/core/gone.mdx"
EXPECT_SKILL_LITERAL="plugin/skills/_doc_links_mutation_fixture/probe.yaml: broken doc path in source -> docs/core/gone.mdx"
EXPECT_PLUGIN_WALK="plugin/_doc_links_mutation_fixture/walkdir_probe.md: broken link -> ../../../docs/core/gone.mdx"
EXPECT_STALE="$STALE_CITING: stale allowlist entry (target exists) -> $STALE_TARGET"

mkdir -p "$(dirname "$LIB_MUT")"
printf '%s\n' "// $GONE" >"$LIB_MUT"
run_checker_must_match "$EXPECT_LIB"
rm -f "$LIB_MUT"

mkdir -p "$SKILL_DIR"
printf '%s\n' '# probe' "[broken](../../../$GONE)" >"$SKILL_MD"
run_checker_must_match "$EXPECT_SKILL_LINK"
rm -rf "$SKILL_DIR"

mkdir -p "$PLUGIN_PROBE_DIR"
printf '%s\n' '# walkDir probe' "[broken](../../../$GONE)" >"$PLUGIN_PROBE_MD"
run_checker_must_match "$EXPECT_PLUGIN_WALK"
rm -rf "$PLUGIN_PROBE_DIR"

mkdir -p "$SKILL_DIR"
printf '%s\n' "# probe" "docs_path: $GONE" >"$SKILL_YAML"
run_checker_must_match "$EXPECT_SKILL_LITERAL"
rm -rf "$SKILL_DIR"

cat >"$ALLOWLIST" <<EOF
{
  "entries": [
    {
      "target": "$STALE_TARGET",
      "citingFile": "$STALE_CITING",
      "reason": "fixture: stale entry when target exists"
    }
  ]
}
EOF
mkdir -p "$(dirname "$STALE_PROBE")"
printf '%s\n' "// $STALE_TARGET" >"$STALE_PROBE"
run_checker_must_match "$EXPECT_STALE"
rm -f "$STALE_PROBE"
cp "$ALLOWLIST_BACKUP" "$ALLOWLIST"

echo "test_docs_links_fixtures: OK"