#!/usr/bin/env bash
# Apply each known-survivor mutation to shipped files, run plan contracts, expect failure.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

PUB_TEST="$ROOT_DIR/tool/contracts/test_release_publish_plan.sh"
RETRY_TEST="$ROOT_DIR/tool/contracts/test_release_runner_retry_plan.sh"

BACKUP_DIR="$(mktemp -d)"
cp tool/release/release_publish_lib.sh \
  tool/release/publish_release_assets.sh \
  tool/release/release_runner_retry_lib.sh \
  tool/release/maybe_rerun_runner_shortage_jobs.sh \
  "$BACKUP_DIR/"

restore() {
  cp "$BACKUP_DIR/"*.sh tool/release/
}

trap restore EXIT

run_both() {
  bash "$PUB_TEST" >/dev/null
  bash "$RETRY_TEST" >/dev/null
}

expect_red() {
  local name="$1"
  if run_both 2>/dev/null; then
    echo "MUTATION $name: GREEN (expected RED)"
    return 1
  fi
  echo "MUTATION $name: RED"
  return 0
}

fail=0
run_both
echo "BASELINE: GREEN"

restore
sed -i '/\[\[ -f "\$old_file" && -f "\$new_file" \]\]/a\  return 0' tool/release/release_publish_lib.sh
expect_red "skip_strict_superset" || fail=1

restore
sed -i 's/checksums_action="upload_new"/checksums_action="clobber_with_draft"/' tool/release/release_publish_lib.sh
expect_red "force_clobber_on_published" || fail=1

restore
sed -i 's/checksums_body+="$(release_publish__checksum_line_from_parts "\$hash" "\$n")"/checksums_body+="$(release_publish__checksum_line_from_parts "\$hash" "\$asset_dir\/\$n")"/' tool/release/release_publish_lib.sh
expect_red "write_checksums_full_paths" || fail=1

restore
sed -i "s/printf 'gh release upload %s --repo %s %q\\\\n'/printf 'gh release upload %s --repo %s --clobber %q\\\\n'/" tool/release/release_publish_lib.sh
expect_red "clobber_published_tarballs" || fail=1

restore
sed -i "s/'.upload_local_names\[\]?/'*'/" tool/release/release_publish_lib.sh
expect_red "upload_all_tarballs_in_dir" || fail=1

restore
sed -i "s/printf 'gh api %s\/annotations/printf 'gh api repos\/__owner\/repo__\/actions\/jobs\/0\/annotations/" tool/release/release_runner_retry_lib.sh
expect_red "annotation_not_check_run_url" || fail=1

restore
sed -i '/printf '\''SKIP: decision=%s\\n'\'' "\$decision"/i\  printf '\''gh run rerun %s --repo %s --failed\\n'\'' "$run_id" "$repo"' tool/release/release_runner_retry_lib.sh
expect_red "retry_always_rerun" || fail=1

restore
sed -i 's/release_runner_retry__classify_job/echo ignore #/' tool/release/release_runner_retry_lib.sh
expect_red "classify_job_drift" || fail=1

restore
exit "$fail"