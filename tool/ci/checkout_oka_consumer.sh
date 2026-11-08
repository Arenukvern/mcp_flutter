#!/usr/bin/env bash
# Temporary unreleased oka SDK integration (oka PR #18). Test-only consumer pin.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
ref="$(tr -d '[:space:]' < "$repo_root/tool/ci/oka_consumer_pin.txt")"
dest="$repo_root/oka"
if [[ -d "$dest/.git" ]]; then
  git -C "$dest" fetch --depth 1 origin "$ref" 2>/dev/null || git -C "$dest" fetch origin "$ref"
  git -C "$dest" checkout --detach "$ref"
else
  git clone "https://github.com/Arenukvern/oka.git" "$dest"
  git -C "$dest" fetch --depth 1 origin "$ref"
  git -C "$dest" checkout --detach "$ref"
fi
echo "oka consumer pin at $ref -> $dest"
