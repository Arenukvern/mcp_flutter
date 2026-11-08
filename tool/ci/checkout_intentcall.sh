#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
ref="$(tr -d '[:space:]' < "$repo_root/tool/ci/intentcall_ref.txt")"
dest="$repo_root/intentcall"
if [[ -d "$dest/.git" ]]; then
  git -C "$dest" fetch --depth 1 origin "$ref"
  git -C "$dest" checkout --detach "$ref"
else
  git clone --depth 1 "https://github.com/Arenukvern/intentcall.git" "$dest"
  git -C "$dest" fetch --depth 1 origin "$ref"
  git -C "$dest" checkout --detach "$ref"
fi
echo "intentcall at $ref -> $dest"
