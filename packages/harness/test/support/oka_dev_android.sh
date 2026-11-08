#!/usr/bin/env bash
# Pub-global `oka dev` delegates to oka_dart_kernel (needs OKA_KERNEL_ROOT).
# Hosted CI uses the ADR-0011 daemon: `oka dev android` (runner-session.json).
set -eu
if [[ "${1:-}" == "dev" && "${2:-}" != "android" ]]; then
  shift
  set -- dev android "$@"
fi
exec oka "$@"
