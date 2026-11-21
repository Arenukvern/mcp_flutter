#!/usr/bin/env bash
# One-stop local gate: runs the full repository contract suite
# (the same checks as `make check-contracts`).
#
# Usage:
#   scripts/check.sh            # full contract gate
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "scripts/check.sh: running make check-contracts"
exec make check-contracts
