#!/usr/bin/env bash
# Reproduce the bounded runtime text-input adoption proof.
# Requires a running showcase app and VM websocket URI.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
toolkit=(dart run "${repo_root}/mcp_server_dart/bin/flutter_mcp_toolkit.dart")

ws_uri="${WS_URI:-${MACOS_WS_URI:-}}"
output="${repo_root}/docs/evidence/generated/mcp_flutter.runtime-enter-text-greeting.redacted.json"
text="steward runtime proof"
branch="$(git -C "${repo_root}" branch --show-current 2>/dev/null || true)"
base_commit="$(git -C "${repo_root}" rev-parse HEAD 2>/dev/null || true)"

usage() {
  cat <<'EOF'
Usage: tool/evals/run_runtime_enter_text_greeting.sh [options]

Options:
  --ws-uri URI       VM websocket URI for a running flutter_test_app showcase
  --output PATH      Evidence JSON path
  --text TEXT        Text to enter (default: steward runtime proof)
  -h, --help         Show this help

Example:
  make showcase
  WS_URI='ws://127.0.0.1:<port>/<token>/ws' \
    tool/evals/run_runtime_enter_text_greeting.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ws-uri) ws_uri="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    --text) text="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 64 ;;
  esac
done

if [[ -z "${ws_uri}" ]]; then
  echo "Set WS_URI or pass --ws-uri for the running showcase VM websocket." >&2
  exit 64
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to emit the redacted proof JSON." >&2
  exit 69
fi

work_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${work_dir}"
}
trap cleanup EXIT

run_tool() {
  "${toolkit[@]}" --vm-service-uri "${ws_uri}" "$@"
}

run_tool doctor --json >"${work_dir}/doctor.json"
run_tool exec --name reveal_search \
  --args '{"query":"greeting_input_field","matchBy":"identifier","direction":"down","maxAttempts":4,"distance":220}' \
  >"${work_dir}/reveal_search.json"

if [[ "$(jq -r '.data.success // false' "${work_dir}/reveal_search.json")" != "true" ]]; then
  echo "Could not reveal semantics identifier greeting_input_field with reveal_search." >&2
  jq '.data' "${work_dir}/reveal_search.json" >&2
  exit 1
fi

ref="$(jq -r '.data.ref' "${work_dir}/reveal_search.json")"
snapshot_id="$(jq -r '.data.snapshotId' "${work_dir}/reveal_search.json")"
run_tool exec --name evaluate_dart_expression \
  --args '{"expression":"AgentState.instance.greeting"}' \
  >"${work_dir}/before.json"
run_tool exec --name enter_text \
  --args "{\"ref\":\"${ref}\",\"snapshotId\":${snapshot_id},\"text\":\"${text}\"}" \
  >"${work_dir}/enter_text.json"
run_tool exec --name evaluate_dart_expression \
  --args '{"expression":"AgentState.instance.greeting"}' \
  >"${work_dir}/after.json"

mkdir -p "$(dirname "${output}")"

jq -n \
  --arg branch "${branch}" \
  --arg baseCommit "${base_commit}" \
  --arg expected "${text}" \
  --arg ref "${ref}" \
  --argjson doctor "$(cat "${work_dir}/doctor.json")" \
  --argjson revealSearch "$(cat "${work_dir}/reveal_search.json")" \
  --argjson before "$(cat "${work_dir}/before.json")" \
  --argjson enter "$(cat "${work_dir}/enter_text.json")" \
  --argjson after "$(cat "${work_dir}/after.json")" \
  '{
    schema: "steward-adoption-runtime-proof/v1",
    capabilityId: "mcp_flutter.runtime.enter-text-greeting",
    status: "adoption_run_passed_capability_candidate",
    recordedAt: (now | todateiso8601),
    subject: {
      repo: "mcp_flutter",
      branch: $branch,
      baseCommit: $baseCommit,
      dirtyState: "caller must inspect git status; this script does not assert clean checkout"
    },
    runtime: {
      platform: "macos",
      launchCommand: "make showcase",
      vmServiceUri: "ws://127.0.0.1:<redacted-port>/<redacted-token>/ws"
    },
    proof: {
      doctor: {
        ok: $doctor.ok,
        total: $doctor.data.summary.total,
        pass: $doctor.data.summary.pass,
        warn: $doctor.data.summary.warn,
        fail: $doctor.data.summary.fail
      },
      discovery: {
        snapshotId: $revealSearch.data.snapshotId,
        selector: {
          identifier: "greeting_input_field",
          ref: $ref,
          type: $revealSearch.data.match.type
        }
      },
      reveal: {
        strategy: "reveal_search",
        tool: "reveal_search",
        targetIdentifier: "greeting_input_field",
        attempts: $revealSearch.data.attempts,
        match: $revealSearch.data.match,
        success: $revealSearch.data.success
      },
      falsifier: {
        expression: "AgentState.instance.greeting",
        before: $before.data.result
      },
      interaction: {
        tool: "enter_text",
        ref: $ref,
        snapshotId: $revealSearch.data.snapshotId,
        text: $expected,
        success: $enter.data.success,
        via: $enter.data.via
      },
      acceptance: {
        expression: "AgentState.instance.greeting",
        expected: $expected,
        actual: $after.data.result,
        passed: ($after.data.result == $expected)
      }
    },
    caveats: [
      "This proves one adoption run, not full H5 capability or repo-wide adoption.",
      "Promote only after a held-out fresh checkout or second-agent repeat."
    ]
  }' >"${output}"

if [[ "$(jq -r '.proof.acceptance.passed' "${output}")" != "true" ]]; then
  echo "Acceptance failed; evidence written to ${output}" >&2
  exit 1
fi

echo "OK: runtime enter-text proof evidence written to ${output}"
