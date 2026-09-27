#!/usr/bin/env bash
# Deprecated wrapper — see packages/harness/tool/showcase.dart (ADR-0015).
# Equivalent to: dart run packages/harness/tool/showcase.dart --stop
# Kept because integration-test support code (mcp_server_dart) invokes it.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec dart run "${here}/../packages/harness/tool/showcase.dart" --stop "$@"
