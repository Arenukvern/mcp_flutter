#!/usr/bin/env bash
# Prints hosted pub.dev dependency snippets for mcp_flutter consumers (Phase 7.5).
set -euo pipefail

version="${INTENTCALL_VERSION:-0.1.0}"

cat <<EOF
# Replace path: ../agentkit/packages/<name> with:

intentcall_schema: ^${version}
intentcall_core: ^${version}
intentcall_session: ^${version}
intentcall_mcp: ^${version}
intentcall_platform: ^${version}
intentcall_codegen: ^${version}
intentcall_webmcp: ^${version}
intentcall_testing: ^${version}
intentcall_gemma: ^${version}
intentcall_apple: ^${version}
intentcall_android: ^${version}
EOF
