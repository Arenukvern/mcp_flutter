#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PUBSPEC_FILE="$ROOT_DIR/mcp_server_dart/pubspec.yaml"
DOCKER_FILE="$ROOT_DIR/mcp_server_dart/Dockerfile"
DOCKER_DEV_FILE="$ROOT_DIR/mcp_server_dart/Dockerfile.dev"

extract_pubspec_min_sdk() {
  sed -nE "s/^[[:space:]]*sdk:[[:space:]]*['\"]?(\^|>=)?([0-9]+\.[0-9]+\.[0-9]+).*/\2/p" "$PUBSPEC_FILE" | head -n 1
}

extract_docker_sdk() {
  local file="$1"
  sed -nE "s/^FROM dart:([0-9]+\.[0-9]+\.[0-9]+)-sdk.*/\1/p" "$file" | head -n 1
}

pubspec_sdk="$(extract_pubspec_min_sdk)"
docker_sdk="$(extract_docker_sdk "$DOCKER_FILE")"
docker_dev_sdk="$(extract_docker_sdk "$DOCKER_DEV_FILE")"

if [[ -z "$pubspec_sdk" || -z "$docker_sdk" || -z "$docker_dev_sdk" ]]; then
  echo "Failed to resolve SDK versions for parity check." >&2
  echo "pubspec_sdk='$pubspec_sdk' docker_sdk='$docker_sdk' docker_dev_sdk='$docker_dev_sdk'" >&2
  exit 1
fi

if [[ "$docker_sdk" != "$pubspec_sdk" ]]; then
  echo "SDK parity failure: Dockerfile uses $docker_sdk but pubspec requires $pubspec_sdk" >&2
  exit 1
fi

if [[ "$docker_dev_sdk" != "$pubspec_sdk" ]]; then
  echo "SDK parity failure: Dockerfile.dev uses $docker_dev_sdk but pubspec requires $pubspec_sdk" >&2
  exit 1
fi

echo "SDK parity check passed."
