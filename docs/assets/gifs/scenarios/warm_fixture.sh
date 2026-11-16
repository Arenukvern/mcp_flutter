#!/usr/bin/env bash
# Start fixture and wait until VM URI is ready (for vhs Hide block).
set -euo pipefail
# shellcheck source=fixture_lib.sh
source "$(dirname "$0")/fixture_lib.sh"
echo "[warm] starting native_layer_capture_fixture on Chrome (headless)…"
start_fixture_chrome
echo "[warm] attached $(read_fixture_vm_uri)"