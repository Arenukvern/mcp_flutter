#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB_MUT="$ROOT/mcp_server_dart/lib/src/_doc_links_mutation_fixture.dart"
SKILL_DIR="$ROOT/plugin/skills/_doc_links_mutation_fixture"
SKILL_MD="$SKILL_DIR/SKILL.md"
SKILL_DIR_TOP="$ROOT/skills/_doc_links_mutation_fixture"

cleanup() {
  rm -f "$LIB_MUT"
  rm -rf "$SKILL_DIR" "$SKILL_DIR_TOP"
}
trap cleanup EXIT

cd "$ROOT"
if ! dart run tool/contracts/check_docs_links.dart; then
  echo "test_docs_links_fixtures: clean tree must pass" >&2
  exit 1
fi

gone="${ROOT}/docs/core/gone.mdx"
gone="${gone#"$ROOT/"}"
mkdir -p "$(dirname "$LIB_MUT")"
printf '%s\n' "// $gone" >"$LIB_MUT"
mkdir -p "$SKILL_DIR"
printf '%s\n' '# probe' "[broken](../../../$gone)" >"$SKILL_MD"

if dart run tool/contracts/check_docs_links.dart; then
  echo "test_docs_links_fixtures: mutation under mcp_server_dart/lib and plugin/skills must fail" >&2
  exit 1
fi

echo "test_docs_links_fixtures: OK"