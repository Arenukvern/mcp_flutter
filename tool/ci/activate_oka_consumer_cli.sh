#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
oka_pkg="$repo_root/oka/packages/oka"
if [[ ! -f "$oka_pkg/pubspec.yaml" ]]; then
  echo "missing $oka_pkg" >&2
  exit 1
fi
dart pub global activate --source path "$oka_pkg"
echo "OKA_BIN=$(command -v oka)"
