#!/usr/bin/env bash
# End-to-end contract tests: publish_release_assets + runner retry vs mock gh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURES="$ROOT_DIR/tool/contracts/fixtures"

fail() { echo "test_release_tooling_e2e: $*" >&2; exit 1; }
ok() { echo "test_release_tooling_e2e: $*"; }

command -v jq >/dev/null 2>&1 || fail "jq required"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

export GITHUB_REPOSITORY="Arenukvern/mcp_flutter"
MOCK_STATE="$tmpdir/gh_state"
mkdir -p "$MOCK_STATE/assets"
cp "$ROOT_DIR/tool/contracts/lib/mock_gh_release_tooling.sh" "$tmpdir/gh"
chmod +x "$tmpdir/gh"
export PATH="$tmpdir:$PATH"
export GH_MOCK_STATE="$MOCK_STATE"

setup_publish_assets() {
  local tag="$1"
  local asset_dir="$tmpdir/dist-$tag"
  rm -rf "$asset_dir"
  mkdir -p "$asset_dir"
  echo "payload-linux" >"$asset_dir/flutter_mcp_7.2.1_linux-x64.tar.gz"
  echo "payload-darwin" >"$asset_dir/flutter_mcp_7.2.1_darwin-arm64.tar.gz"
  mkdir -p "$MOCK_STATE/assets/$tag"
  : >"$MOCK_STATE/assets/$tag/names.txt"
  rm -f "$MOCK_STATE/draft_$tag"
  printf '%s' "$asset_dir"
}

assert_checksums_format() {
  local asset_dir="$1"
  local checksums="$asset_dir/checksums.txt"
  [[ -f "$checksums" ]] || fail "missing checksums.txt"
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    [[ "$line" =~ ^[0-9a-f]{64}\ \ [^/]+$ ]] || \
      fail "checksum line must be hash + basename, got: $line"
  done <"$checksums"
  local archive="flutter_mcp_7.2.1_linux-x64.tar.gz"
  grep -q " ${archive}\$" "$checksums" || fail "install.sh-style grep miss for $archive"
  (
    cd "$asset_dir"
    sha256sum -c checksums.txt
  ) || fail "sha256sum -c failed in asset dir"
}

# --- publish: empty published release ---
tag="v7.2.1"
asset_dir="$(setup_publish_assets "$tag")"
bash "$ROOT_DIR/tool/release/publish_release_assets.sh" "$tag" "$asset_dir" \
  || fail "publish empty published"
assert_checksums_format "$asset_dir"
grep -qxF checksums.txt "$MOCK_STATE/assets/$tag/names.txt" || fail "checksums uploaded"
ok "publish empty published release"

# --- publish: partial (one remote tarball, matching hash) ---
tag="v7.2.1-partial"
asset_dir="$(setup_publish_assets "$tag")"
linux="$asset_dir/flutter_mcp_7.2.1_linux-x64.tar.gz"
mkdir -p "$MOCK_STATE/assets/$tag"
cp "$linux" "$MOCK_STATE/assets/$tag/flutter_mcp_7.2.1_linux-x64.tar.gz"
echo flutter_mcp_7.2.1_linux-x64.tar.gz >"$MOCK_STATE/assets/$tag/names.txt"
bash "$ROOT_DIR/tool/release/publish_release_assets.sh" "$tag" "$asset_dir" \
  || fail "publish partial"
assert_checksums_format "$asset_dir"
ok "publish partial published release"

# --- publish: draft clobber ---
tag="v7.2.1-draft"
asset_dir="$(setup_publish_assets "$tag")"
touch "$MOCK_STATE/draft_$tag"
echo stale >"$MOCK_STATE/assets/$tag/checksums.txt"
echo checksums.txt >"$MOCK_STATE/assets/$tag/names.txt"
bash "$ROOT_DIR/tool/release/publish_release_assets.sh" "$tag" "$asset_dir" \
  || fail "publish draft"
assert_checksums_format "$asset_dir"
ok "publish draft clobber"

# --- publish: checksum mismatch on published asset must fail ---
tag="v7.2.1-mismatch"
asset_dir="$(setup_publish_assets "$tag")"
mkdir -p "$MOCK_STATE/assets/$tag"
echo wrong >"$MOCK_STATE/assets/$tag/flutter_mcp_7.2.1_linux-x64.tar.gz"
echo flutter_mcp_7.2.1_linux-x64.tar.gz >"$MOCK_STATE/assets/$tag/names.txt"
if bash "$ROOT_DIR/tool/release/publish_release_assets.sh" "$tag" "$asset_dir" 2>/dev/null; then
  fail "expected checksum mismatch failure"
else
  ok "publish rejects remote checksum mismatch"
fi

# --- retry: superseded ---
export GH_MOCK_RUN_JSON
GH_MOCK_RUN_JSON="$(jq -n \
  --arg hb "v7.2.1" \
  --arg ts "2026-11-17T10:00:00Z" \
  '{head_branch: $hb, created_at: $ts}')"
export GH_MOCK_WORKFLOW_RUNS_JSON
GH_MOCK_WORKFLOW_RUNS_JSON="$(jq '.workflow_runs |= map(.head_branch="v7.2.1")' \
  "$FIXTURES/release_superseded_runs.json")"
export GH_MOCK_JOBS_JSON='{"jobs":[]}'
summary="$tmpdir/superseded.md"
GITHUB_STEP_SUMMARY="$summary" \
  bash "$ROOT_DIR/tool/release/maybe_rerun_runner_shortage_jobs.sh" \
  100 "$GITHUB_REPOSITORY" 1 3 >/dev/null || fail "retry superseded"
grep -q superseded "$summary" || fail "superseded summary missing"
ok "retry superseded run exits without rerun"

# --- retry: manual cancel short queue ---
export GH_MOCK_RUN_JSON='{"head_branch":"v7.2.1","created_at":"2026-11-17T09:00:00Z"}'
export GH_MOCK_WORKFLOW_RUNS_JSON='{"workflow_runs":[]}'
job="$(cat "$FIXTURES/release_job_manual_cancel_short.json")"
export GH_MOCK_JOBS_JSON="$(jq -n --argjson j "$job" '{jobs: [$j]}')"
summary="$tmpdir/manual.md"
GITHUB_STEP_SUMMARY="$summary" \
  bash "$ROOT_DIR/tool/release/maybe_rerun_runner_shortage_jobs.sh" \
  101 "$GITHUB_REPOSITORY" 1 3 >/dev/null
grep -qE 'non-shortage|no runner-shortage' "$summary" || \
  fail "manual cancel should not classify shortage"
ok "retry manual cancel short queue"

# --- retry: zero-step long queue (shortage) dispatches rerun ---
export GH_MOCK_RUN_JSON='{"head_branch":"v7.2.1","created_at":"2026-11-17T09:00:00Z"}'
export GH_MOCK_WORKFLOW_RUNS_JSON='{"workflow_runs":[]}'
job="$(cat "$FIXTURES/release_job_runner_shortage_long_queue.json")"
export GH_MOCK_JOBS_JSON="$(jq -n --argjson j "$job" '{jobs: [$j]}')"
export GH_MOCK_ANNOTATIONS_JSON='[]'
: >"$MOCK_STATE/rerun.log"
summary="$tmpdir/shortage.md"
RUNNER_RETRY_SKIP_BACKOFF=1 GITHUB_STEP_SUMMARY="$summary" \
  bash "$ROOT_DIR/tool/release/maybe_rerun_runner_shortage_jobs.sh" \
  102 "$GITHUB_REPOSITORY" 2 3 >/dev/null \
  || fail "retry shortage should dispatch"
grep -q "Classified runner shortage (zero steps" "$summary" || \
  fail "long queue job must classify as shortage"
[[ -s "$MOCK_STATE/rerun.log" ]] || fail "gh run rerun not invoked"
ok "retry classifies long zero-step cancel and reruns"

ok "release tooling e2e OK"
