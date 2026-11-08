# Universal automation dependency policy (hosted)

This workspace resolves **hosted** `universal_automation_*` packages from pub.dev:

- `universal_automation_interface` **0.3.0** (latest published interface)
- `universal_automation_semantics` **0.2.0**

**Blocker:** semantics **0.4+** / lens APIs require `universal_automation_interface` **^0.4.0**, which is **not** published on pub.dev. Until interface 0.4 ships, `mcp_server_dart` keeps lens rendering (`standard` / `compact` / `design`) via the in-repo compatibility adapter in `mcp_server_dart/lib/src/shared_core/semantic_lens_render_adapter.dart` (UA semantics grammar @ `1c6f7982`).

Do not add git `dependency_overrides` for UA packages in this consumer repo.
