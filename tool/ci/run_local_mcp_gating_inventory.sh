#!/usr/bin/env bash
# Full applicable workspace suite inventory (commands + exit codes + provenance).
set -euo pipefail
here="$(cd "$(dirname "$0")/../.." && pwd)"
repo_root="$here"
log="${MCP_INVENTORY_LOG:-/cursor/stores/self/local_mcp_gating_inventory_full.log}"
cd "$repo_root"

meta_section() {
  echo "== META: repo + oka pin =="
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "mcp_flutter_git_head=$(git rev-parse HEAD)"
  echo "mcp_flutter_dirty_sha256=$(git status --porcelain | sha256sum | awk '{print $1}')"
  if [[ -f tool/ci/oka_consumer_pin.txt ]]; then
    echo "oka_consumer_pin=$(tr -d '[:space:]' < tool/ci/oka_consumer_pin.txt)"
  fi
  if [[ -d oka/.git ]]; then
    echo "oka_checkout_head=$(git -C oka rev-parse HEAD 2>/dev/null || echo missing)"
  fi
}

run_section() {
  local title=$1
  shift
  echo ""
  echo "== $title =="
  echo "command=$*"
  set +e
  "$@"
  local ec=$?
  set -e
  echo "exit_status=$ec"
  return "$ec"
}

failed=0
: >"$log"
{
  meta_section
  if [[ -f tool/ci/oka_consumer_pin.txt ]]; then
    run_section "provision oka consumer pin" bash tool/ci/provision_oka_consumer_test_pin.sh || failed=1
  fi
  run_section "flutter pub get (workspace root)" flutter pub get || failed=1

  run_section "dart analyze packages/harness (fatal-infos)" \
    dart analyze --fatal-infos packages/harness || failed=1
  run_section "packages/harness unit (excl native tags)" \
    bash -c 'cd packages/harness && dart test --exclude-tags native-android,native-linux,compile-repro-opt-in' || failed=1

  for pkg in \
    showcase/native_layer_capture_fixture \
    showcase/drivers \
    jaspr_web_example \
    mcp_toolkit \
    packages/core \
    packages/server_capability_kernel \
    packages/server_capability_core \
    mcp_server_dart
  do
    if [[ ! -f "$pkg/pubspec.yaml" ]]; then
      echo "== SKIP $pkg (no pubspec.yaml) =="
      echo "reason=unsupported_missing_pubspec"
      continue
    fi
    if [[ "$pkg" == mcp_toolkit || "$pkg" == showcase/* ]]; then
      run_section "$pkg flutter pub get" bash -c "cd $pkg && flutter pub get" || failed=1
      run_section "$pkg dart analyze" dart analyze "$pkg" || failed=1
      run_section "$pkg flutter test" bash -c "cd $pkg && flutter test" || failed=1
    elif [[ "$pkg" == mcp_server_dart ]]; then
      run_section "$pkg flutter pub get" bash -c "cd $pkg && flutter pub get" || failed=1
      run_section "$pkg dart test (full)" bash -c "cd $pkg && dart test" || failed=1
      run_section "$pkg dart test test/contract" bash -c "cd $pkg && dart test test/contract/" || failed=1
    else
      run_section "$pkg dart pub get" bash -c "cd $pkg && dart pub get" || failed=1
      run_section "$pkg dart analyze" dart analyze "$pkg" || failed=1
      run_section "$pkg dart test" bash -c "cd $pkg && dart test" || failed=1
    fi
  done

  if [[ -d oka/packages/oka_harness ]]; then
    run_section "oka_harness (pinned)" bash -c 'cd oka/packages/oka_harness && dart test' || failed=1
  else
    echo "== SKIP oka_harness (oka checkout missing) =="
  fi
  if [[ -d oka/packages/oka_android ]]; then
    run_section "oka_android stop+binding+teardown (pinned)" bash -c 'cd oka/packages/oka_android && dart test test/runner_session_spawn_binding_test.dart test/dev_session_stop_test.dart test/dev_session_teardown_test.dart' || failed=1
    run_section "oka_android dart analyze fatal-infos" bash -c 'cd oka/packages/oka_android && dart analyze --fatal-infos .' || failed=1
  fi

  # Workspace-declared packages not individually covered above
  for pkg in packages/harness; do
    [[ -f "$pkg/pubspec.yaml" ]] || continue
    echo "== NOTE $pkg covered by harness unit section =="
  done

  for optional in showcase/flutter_demo showcase/flutter_test_app; do
    if [[ -f "$optional/pubspec.yaml" ]]; then
      echo "== OPTIONAL (not in default inventory): $optional — run manually if needed =="
    fi
  done

  if [[ "$failed" -eq 0 ]]; then
    echo "OK local mcp gating inventory (all sections exit 0)"
  else
    echo "INVENTORY_COMPLETED_WITH_FAILURES exit_aggregate=1"
    exit 1
  fi
} 2>&1 | tee -a "$log"
