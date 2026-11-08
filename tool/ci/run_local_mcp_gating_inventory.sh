#!/usr/bin/env bash
# Local inventory: Contract Gates gating jobs + sibling packages (no expectation weakening).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"

if [[ -f tool/ci/oka_consumer_pin.txt ]]; then
  bash tool/ci/provision_oka_consumer_test_pin.sh
fi
flutter pub get

echo "== dart analyze packages/harness (fatal-infos) =="
dart analyze --fatal-infos packages/harness

echo "== packages/harness unit (excl native) =="
(cd packages/harness && dart test --exclude-tags native-android,native-linux,compile-repro-opt-in)

echo "== showcase/native_layer_capture_fixture =="
(cd showcase/native_layer_capture_fixture && flutter pub get && dart analyze . && flutter test)

echo "== mcp_toolkit (Flutter package; flutter test) =="
(cd mcp_toolkit && flutter pub get && dart analyze . && flutter test)

echo "== packages/core (pure Dart) =="
(cd packages/core && dart pub get && dart analyze . && dart test)

echo "== oka_harness (pinned consumer graph) =="
if [[ -d oka/packages/oka_harness ]]; then
  (cd oka/packages/oka_harness && dart test)
fi

echo "== oka_android stop + spawn binding (pinned) =="
if [[ -d oka/packages/oka_android ]]; then
  (
    cd oka/packages/oka_android
    dart test test/runner_session_spawn_binding_test.dart test/dev_session_stop_test.dart
  )
fi

echo "== mcp_server_dart (full; matches contract_gates) =="
(
  cd mcp_server_dart
  flutter pub get
  export HOME="${HOME:-/tmp}"
  export DART_SUPPRESS_ANALYTICS=true
  dart test
)

echo "== server_capability_kernel + server_capability_core =="
dart test packages/server_capability_kernel packages/server_capability_core

echo "== mcp_server_dart contract =="
(cd mcp_server_dart && dart test test/contract/)

echo "OK local mcp gating inventory"
