#!/usr/bin/env bash
# Prints hosted pub.dev dependency snippets for mcp_flutter consumers (Phase 7.5).
set -euo pipefail

version="${AGENTKIT_VERSION:-0.1.0}"

cat <<EOF
# Replace path: ../agentkit/packages/<name> with:

agentkit_schema: ^${version}
agentkit_core: ^${version}
agentkit_mcp: ^${version}
agentkit_platform: ^${version}
agentkit_codegen: ^${version}
agentkit_webmcp: ^${version}
agentkit_testing: ^${version}
agentkit_gemma: ^${version}
agentkit_apple: ^${version}
agentkit_android: ^${version}
EOF
