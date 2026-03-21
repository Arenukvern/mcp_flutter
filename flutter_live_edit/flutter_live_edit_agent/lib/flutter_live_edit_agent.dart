/// Server-side live edit agent: **paths** resolve files in the workspace;
/// **`from_json_to_json`** normalizes loose JSON maps; **`compactJson`** only
/// shrinks payloads for model prompts (not wire codecs).
library;

export 'src/live_edit_agent_service.dart';
