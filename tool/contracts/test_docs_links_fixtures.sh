#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROBE="$ROOT/mcp_server_dart/lib/src/_doc_links_mutation_probe.dart"

cleanup() {
  rm -f "$PROBE"
}
trap cleanup EXIT

cd "$ROOT"
if dart run tool/contracts/check_docs_links.dart; then
  :
else
  echo "test_docs_links_fixtures: clean tree must pass" >&2
  exit 1
fi

mkdir -p "$(dirname "$PROBE")"
cp "$ROOT/tool/contracts/fixtures/docs_links/probe_comment.txt" "$PROBE"
if DOC_LINKS_MUTATION_PROBE=1 dart run tool/contracts/check_docs_links.dart; then
  echo "test_docs_links_fixtures: mutation should fail" >&2
  exit 1
fi

echo "test_docs_links_fixtures: OK"