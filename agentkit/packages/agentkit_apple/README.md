> ⚠️ **Pre-release (0.1.x)** — Highly experimental. APIs may change without notice. Not for production. [Details](../../PRE_RELEASE.md).


# agentkit_apple

Apple platform manifest codegen for agentkit (App Intents / Shortcuts export).

## Author workflow

1. **Author tools** — hand-written `AgentCallEntry` or optional `@AgentTool` codegen (`agentkit_codegen`).
2. **Collect descriptors** — `entry.toRegistration().descriptor` or registry snapshot.
3. **Generate manifest** — `generateAppleAgentManifest(descriptors)` → `agent_manifest.json`.
4. **Platform snippet** — map manifest intents to Shortcuts / App Intents plist entries.

```dart
import 'package:agentkit_apple/agentkit_apple.dart';

final json = generateAppleAgentManifest([
  entry.toRegistration().descriptor,
]);
// write to ios/Runner/agent_manifest.json
```

Example Swift-oriented snippet derived from manifest (hand-off to Xcode codegen):

```swift
// agent_manifest.json → App Intents (illustrative)
// Intent: app_demo_ping — "Returns pong for a message"
// Parameters: message (String, required)
```

Input: `agent_manifest.json` (`platform: apple`, `intents[]`).  
Output: JSON manifest + documented Swift/Info.plist mapping for Siri/Shortcuts.

See `test/agent_manifest_generator_test.dart`.