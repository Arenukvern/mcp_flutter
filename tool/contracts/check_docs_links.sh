#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

command -v rg >/dev/null 2>&1 || {
  echo "check_docs_links: rg required" >&2
  exit 1
}

dart run "$ROOT_DIR/tool/contracts/check_docs_links.dart"