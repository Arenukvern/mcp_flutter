#!/usr/bin/env bash
# Run N dogfood eval iterations with merge (warm path requires live WS_URI).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
count="${1:-5}"

if [[ -z "${WS_URI:-}" ]]; then
  echo "Set WS_URI from web-showcase log, e.g.:" >&2
  echo "  DOGFOOD_VISUAL=1 make -C ${repo_root} web-showcase" >&2
  echo "  export WS_URI=\$(grep -Eo 'ws://127\\.0\\.0\\.1:[0-9]+/[A-Za-z0-9_=-]+/ws' ${repo_root}/.showcase/web_app.log | tail -1)" >&2
  exit 1
fi

export HARNESS_ROOT="${HARNESS_ROOT:-${repo_root}/../flutter_harness}"
export VISUAL_HS="${VISUAL_HS:-${HARNESS_ROOT}/harness/examples/visual_reconstruct/warm_path_direct.hs.yaml}"

for i in $(seq 1 "${count}"); do
  printf '\n[dogfood-iter] ===== iteration %s/%s =====\n' "${i}" "${count}"
  if ! bash "${here}/run_dogfood_eval.sh" --ws-uri "${WS_URI}" --merge --webmcp-verify; then
    printf '[dogfood-iter] iteration %s failed (see eval_runs/)\n' "${i}" >&2
  fi
  sleep 2
done

echo "[dogfood-iter] done ${count} iterations; tracker: ${repo_root}/.showcase/dogfood_web_eval.yaml"
