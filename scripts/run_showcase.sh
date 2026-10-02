#!/usr/bin/env bash
# Deprecated wrapper — the showcase moved to packages/harness/tool/showcase.dart
# (ADR-0015). This wrapper keeps existing references working; the canonical
# entrypoints are now:
#   make showcase        ==  dart run packages/harness/tool/showcase.dart
#   make showcase-stop   ==  dart run packages/harness/tool/showcase.dart --stop
#   make web-showcase    ==  dart run packages/harness/tool/showcase.dart --web
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec dart run "${here}/../packages/harness/tool/showcase.dart" "$@"
