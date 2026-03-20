#!/usr/bin/env bash
# Build Agentic Executables knowledge packs from Live Edit docs (Know + Use model).
# Prereq: clone https://github.com/fluent-meaning-symbiotic/agentic_executables or set AE_ROOT.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AE_ROOT="${AE_ROOT:-${HOME}/mcp/agentic_executables}"
CLI="${AE_ROOT}/agentic_executables_cli"
HUB="${LIVE_EDIT_AE_HUB:-${REPO_ROOT}/.ae_hub}"

if [[ ! -f "${CLI}/bin/ae.dart" ]]; then
  echo "Expected AE CLI at ${CLI}/bin/ae.dart — set AE_ROOT or install agentic_executables." >&2
  exit 1
fi

(cd "${CLI}" && dart pub get >/dev/null)

run_ae() {
  (cd "${CLI}" && dart run bin/ae.dart "$@")
}

if [[ ! -d "${HUB}" ]]; then
  echo "Initializing AE hub at ${HUB}"
  run_ae hub init --path "${HUB}"
fi

build_doc() {
  local rel="$1"
  local name="$2"
  local abs="${REPO_ROOT}/${rel}"
  if [[ ! -f "${abs}" ]]; then
    echo "Missing ${abs}" >&2
    exit 1
  fi
  echo "ae know build --name ${name} --path ${abs}"
  run_ae know build \
    --path "${abs}" \
    --name "${name}" \
    --hub "${HUB}" \
    --on-conflict reuse \
    --format markdown
}

build_doc "flutter_live_edit/PRD.md" live_edit_prd
build_doc "flutter_live_edit/USER_STORY.md" live_edit_user_story
build_doc "flutter_live_edit/CONTRACT.md" live_edit_contract
build_doc "flutter_live_edit/BOUNDARIES.md" live_edit_boundaries

echo "Done. Hub: ${HUB} — list: (cd ${CLI} && dart run bin/ae.dart know list --hub \"${HUB}\")"
