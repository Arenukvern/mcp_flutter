#!/usr/bin/env bash
# Prints hosted pub.dev dependency snippets for mcp_flutter consumers.
# Maintainer dogfood uses sibling agentkit path deps; external apps use hosted.
set -euo pipefail

version="${INTENTCALL_VERSION:-0.6.0}"

cat <<EOF
# External app authors (hosted pub.dev):

intentcall_schema: ^${version}
intentcall_core: ^${version}
intentcall_session: ^${version}
intentcall_mcp: ^${version}
intentcall_platform: ^${version}
intentcall_platform_sync: ^${version}
intentcall_hooks: ^${version}
intentcall_bridge: ^${version}
intentcall_codegen: ^${version}
intentcall_cli: ^${version}
intentcall_webmcp: ^${version}
intentcall_testing: ^${version}

# Endorsed federated impls (usually transitive via intentcall_platform):
# intentcall_platform_apple: ^${version}
# intentcall_platform_android: ^${version}

# Example-only (not on the publish train):
# intentcall_gemma: path or workspace-only

# Deleted — do not depend on:
# intentcall_apple / intentcall_android (use intentcall_platform + platform_sync)
EOF
