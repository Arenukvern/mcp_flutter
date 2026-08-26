# Changelog

<!-- markdownlint-disable MD052 -->
<!-- Keep a Changelog version headings use [3.0.1] brackets; MD052 treats them as reference links. -->

## [5.1.0](https://github.com/Arenukvern/mcp_flutter/compare/v5.0.4...v5.1.0) (2026-08-23)


### Features

* logo ([bfeae14](https://github.com/Arenukvern/mcp_flutter/commit/bfeae14596201d531198f6e94b045aae5dbd1926))


### Bug Fixes

* **contracts:** address second review round on mcp-registry checks ([333d788](https://github.com/Arenukvern/mcp_flutter/commit/333d7884e26c87b6320337732a5820ffbb006c97))
* **contracts:** harden mcp-registry checks per review ([6b0e32b](https://github.com/Arenukvern/mcp_flutter/commit/6b0e32b2ab907649ab6f898cf011d35c001b4808))


### Documentation

* ADR 0013 — MCP Registry publish hardening + fmt.check.mcp-registry gate ([299e4f4](https://github.com/Arenukvern/mcp_flutter/commit/299e4f4a69c1a26f8ba2d8f6d1c420d584896d62))
* ADR 0013 — MCP Registry publish hardening + fmt.check.mcp-registry gate ([0e14e4d](https://github.com/Arenukvern/mcp_flutter/commit/0e14e4d0dddc7d6aac8eea3632557f72494ef709))

## [5.0.4](https://github.com/Arenukvern/mcp_flutter/compare/v5.0.3...v5.0.4) (2026-08-23)


### Bug Fixes

* **mcp-registry:** drop registryBaseUrl from OCI package entry ([fdb87d3](https://github.com/Arenukvern/mcp_flutter/commit/fdb87d36f945f1573b1b3af71e732d98d9b5bf15))
* **mcp-registry:** drop registryBaseUrl from OCI package entry ([2e6365a](https://github.com/Arenukvern/mcp_flutter/commit/2e6365a88198e7316760fa062ac72897e552dd83))

## [5.0.3](https://github.com/Arenukvern/mcp_flutter/compare/v5.0.2...v5.0.3) (2026-08-23)


### Bug Fixes

* **mcp-registry:** resolve deps inside pinned image, drop lockfile enforcement ([381f13b](https://github.com/Arenukvern/mcp_flutter/commit/381f13b482c96fd5b15dce6a20a504c81657c497))
* **mcp-registry:** resolve deps inside pinned image, drop lockfile enforcement ([3f7d6a1](https://github.com/Arenukvern/mcp_flutter/commit/3f7d6a1cb4fd6c490ca304e03a011639b05f5bfc))

## [5.0.2](https://github.com/Arenukvern/mcp_flutter/compare/v5.0.1...v5.0.2) (2026-08-23)


### Bug Fixes

* **contracts:** check flutter availability in skill assets drift script ([b891998](https://github.com/Arenukvern/mcp_flutter/commit/b891998c82dc6376398c3f9e7d57a7874cbd91f9))
* **contracts:** match corrected Dockerfile.registry path in check_mcp_registry ([9d1cde0](https://github.com/Arenukvern/mcp_flutter/commit/9d1cde0e9488d3139172b59d175e9de94826c96c))
* **contracts:** match corrected Dockerfile.registry path in check_mcp_registry ([dfcd371](https://github.com/Arenukvern/mcp_flutter/commit/dfcd3710292169fd8f40bcd561745e44fc80c78e))
* **mcp-registry:** build image from monorepo context with Flutter SDK ([6c952a7](https://github.com/Arenukvern/mcp_flutter/commit/6c952a74aff73817dcab8ccaae610e6bbf4840ee))

## [5.0.1](https://github.com/Arenukvern/mcp_flutter/compare/v5.0.0...v5.0.1) (2026-08-22)


### Bug Fixes

* **ci:** use explicit path for Dockerfile.registry in build-push action ([b3c8310](https://github.com/Arenukvern/mcp_flutter/commit/b3c8310c70b413236f0cdb5b229713784680ebe8))
* **ci:** use explicit path for Dockerfile.registry in build-push action ([7cb7b67](https://github.com/Arenukvern/mcp_flutter/commit/7cb7b67d7d1c6c8b43a967185d7915d798aff2a1))

## [5.0.0](https://github.com/Arenukvern/mcp_flutter/compare/v4.0.0...v5.0.0) (2026-08-22)


### ⚠ BREAKING CHANGES

* **agentkit:** remove MCPCallEntry from mcp_toolkit

### Features

* add steward hosted dependency gate ([3b91408](https://github.com/Arenukvern/mcp_flutter/commit/3b91408f266480d7822df409c2efbfc34f45e99f))
* **agentkit:** complete in-repo integration gate (Bar D follow-up) ([58df0fe](https://github.com/Arenukvern/mcp_flutter/commit/58df0fe2fd32c7bee26d67733786b296ac099a3d))
* **agentkit:** complete Phase 2 transport-free tool handlers ([76e0209](https://github.com/Arenukvern/mcp_flutter/commit/76e0209192d96da9fc4ec337c6c1f9e4dd37c8f9))
* **agentkit:** complete Phase 3 adapters and transport-free resources ([111c0bf](https://github.com/Arenukvern/mcp_flutter/commit/111c0bf6535f99b4d39f5bc4c5f285e910a62add))
* **agentkit:** consolidate MCP attach via AgentRuntime (Phase 5-B) ([8eaeb1b](https://github.com/Arenukvern/mcp_flutter/commit/8eaeb1be0d230e8d2c32daab579a7f8ee8bf46e9))
* **agentkit:** enhance input schema validation and dynamic registry functionality ([8a6bcee](https://github.com/Arenukvern/mcp_flutter/commit/8a6bcee64d51267a3eaaad115c95659e52db6e3f))
* **agentkit:** enhance Phase 7 extract and integration tooling ([bdfe2a0](https://github.com/Arenukvern/mcp_flutter/commit/bdfe2a039f4776042014a72ee739d744bf92a1fc))
* **agentkit:** migrate agent-entries CLI and docs ([0910443](https://github.com/Arenukvern/mcp_flutter/commit/091044356c7bfa3ab548d803c2c07c0b18193ee2))
* **agentkit:** native platform sync emitters ([0633da3](https://github.com/Arenukvern/mcp_flutter/commit/0633da3239ef8222e0f4dcc2b524832bdb8bb38d))
* **agentkit:** Phase 1 core, MCP adapter, and Phase 3 stubs ([007fa5e](https://github.com/Arenukvern/mcp_flutter/commit/007fa5e0af495c402eb1ad37ce5c09f73f84ea95))
* **agentkit:** Phase 5-C authoring and optional @AgentTool codegen ([e340db8](https://github.com/Arenukvern/mcp_flutter/commit/e340db8674568b136cf2db99d6f9f93896641cda))
* **agentkit:** registry-backed app errors resource template ([7677239](https://github.com/Arenukvern/mcp_flutter/commit/7677239035ee39979fbacdd2698a0ede69c3a746))
* **agentkit:** remove MCPCallEntry from mcp_toolkit ([9823430](https://github.com/Arenukvern/mcp_flutter/commit/98234309b6a89ae38587a47c93f713c4d02866ce))
* **agentkit:** server fmt tool via @AgentTool codegen ([d835a02](https://github.com/Arenukvern/mcp_flutter/commit/d835a0203d2bc503a0501922e16ab46e1e67cd32))
* **agentkit:** web platform sync (WebMCP JS + manifest + Dart path) ([f3614b0](https://github.com/Arenukvern/mcp_flutter/commit/f3614b0593355dd8863c0b3a8bf722690703011a))
* **capability_core:** migrate debug_dump_* tools (gated on dumps_supported) ([397b1eb](https://github.com/Arenukvern/mcp_flutter/commit/397b1eb1b6cfb878cff08edadfb7cb84214a0c74))
* **capability_core:** migrate enter_text, scroll, long_press, swipe, drag, hover, press_key to CoreCapability ([0613295](https://github.com/Arenukvern/mcp_flutter/commit/06132952f5797c088db409eb323275a629e33a13))
* **capability_core:** migrate fill_form with pattern-A handler ([9e71dd0](https://github.com/Arenukvern/mcp_flutter/commit/9e71dd0f9ab4199d7ba26e88adceeee2cc61c054))
* **capability_core:** migrate get_screenshots, capture_ui_snapshot with onSuccess multi-content translation ([0042aeb](https://github.com/Arenukvern/mcp_flutter/commit/0042aeb5cdf20bc1aebd5193ccf3ae8808e732d5))
* **capability_core:** migrate hot_restart_flutter, evaluate_dart_expression, hot_reload_and_capture ([1cff622](https://github.com/Arenukvern/mcp_flutter/commit/1cff622d271a54184c4d2bf8319c08dfd57ec817))
* **capability_core:** migrate navigation, log, semantic, inspection tools (T4-C) ([0ebe466](https://github.com/Arenukvern/mcp_flutter/commit/0ebe46695141720253042bd39d040a54ad08861e))
* **capability_core:** migrate tap_widget as the pattern reference ([9c6ac55](https://github.com/Arenukvern/mcp_flutter/commit/9c6ac5544b82b126596e914605d2deae7bae1683))
* **capability_core:** migrate wait_for with pattern-A handler ([97ae074](https://github.com/Arenukvern/mcp_flutter/commit/97ae074c698a9ec335de6951a98b0435811c7b34))
* **capability_core:** scaffold package with empty CoreCapability ([eed7099](https://github.com/Arenukvern/mcp_flutter/commit/eed70993242a70b9ea45135bdc2e54f48c97a5e9))
* **capability-core:** T4-D-3 — migrate 5 Flutter inspector tools ([79b0268](https://github.com/Arenukvern/mcp_flutter/commit/79b026848d961509d92bbe46aa4ff41630516e02))
* **cli/codegen_snippets:** bundle Flutter main.dart init snippet ([38e6b51](https://github.com/Arenukvern/mcp_flutter/commit/38e6b51c5168e32cf18fa03a9ab8bb8ec25aa589))
* **cli/init_mode_detector:** pure mode-decision logic ([d4293b4](https://github.com/Arenukvern/mcp_flutter/commit/d4293b456b71428608ed3b0614dea9f0bfa3b649))
* **cli/init_mode:** InitMode enum + parse ([977b78e](https://github.com/Arenukvern/mcp_flutter/commit/977b78ec487cc73e2c2cd1f06100723476153ae3))
* **cli/init_target:** InitTarget enum ([2f26f43](https://github.com/Arenukvern/mcp_flutter/commit/2f26f439dda667dfafdd1294af149462d615511b))
* **cli/init_writers:** write skills + manifests per target ([191ac83](https://github.com/Arenukvern/mcp_flutter/commit/191ac8301f99a0d0d27ade3649dff2636c6063cc))
* **cli/mode_prelude:** substitute prelude marker by mode ([0157c01](https://github.com/Arenukvern/mcp_flutter/commit/0157c01afc11ce4e5807f0b529e1df4cf39848ea))
* **cli:** codegen-init command emits Flutter main.dart snippet ([99e21ac](https://github.com/Arenukvern/mcp_flutter/commit/99e21ac3ae9cece5fa27b1a990fbe870c5a14de6))
* **cli:** expose 'init' subcommand ([b46a394](https://github.com/Arenukvern/mcp_flutter/commit/b46a3943c55214fedd7889b70240be6542c92931))
* **cli:** runInit dispatches to per-target writers ([b349ad9](https://github.com/Arenukvern/mcp_flutter/commit/b349ad94968a749e83eaf27844ff784e365d5bfa))
* **contracts:** restore Apple runner compile gate ([b48c92a](https://github.com/Arenukvern/mcp_flutter/commit/b48c92a2bb5f486fae2533c1731363724cb548ff))
* **contracts:** tool-surface snapshot pinned to expected_tool_surface.txt ([be97780](https://github.com/Arenukvern/mcp_flutter/commit/be9778097b0c6456565f16e6567a7fd5a6470612))
* **core_capability:** rename MCP tool prefix core_ → fmt_ ([5c18563](https://github.com/Arenukvern/mcp_flutter/commit/5c1856365182fa4c2da52b6efceaa1e8a4e3b6c4))
* enhance visual capture capabilities for macOS and web ([8d5b199](https://github.com/Arenukvern/mcp_flutter/commit/8d5b1998cfab59eb4af7bdda0df473441d4969ce))
* **gestures:** platform-appropriate pointer kind for drag ([d80ff25](https://github.com/Arenukvern/mcp_flutter/commit/d80ff259fdf51901a75db02e40927065bc306bd6))
* **gestures:** platform-appropriate pointer kind for drag. Made by hi [@dipsy](https://github.com/dipsy) in https://github.com/Arenukvern/mcp_flutter/pull/117 ([f062b3e](https://github.com/Arenukvern/mcp_flutter/commit/f062b3e5576c77c8594ba2aa1115d776774537cf))
* initial native capture ([3ff2d73](https://github.com/Arenukvern/mcp_flutter/commit/3ff2d732ab0911811d1861876cefbfce0caac1df))
* **kernel:** define Capability + CapabilityContext + HostService contracts ([494656c](https://github.com/Arenukvern/mcp_flutter/commit/494656c3cca84e153ed8b60a7cebd19c9ac52a2c))
* **kernel:** expose FakeCommandRunner via testing library (I2) ([2995f2a](https://github.com/Arenukvern/mcp_flutter/commit/2995f2a1a1151da0eb28b806db012355b84920b3))
* **kernel:** id + prefix validators with full test coverage ([9dfeefa](https://github.com/Arenukvern/mcp_flutter/commit/9dfeefabf1c618d295e9a217f625d102e55d25b0))
* **kernel:** scaffold mcp_capability_kernel package ([69ae09c](https://github.com/Arenukvern/mcp_flutter/commit/69ae09cfeb1f7e26d46e90b52159f9cfd5ac9a32))
* **live_edit_models:** scaffold pure-Dart shared models package ([020e848](https://github.com/Arenukvern/mcp_flutter/commit/020e8489acdee46ab0ed7ce43c4e01b33563ba57))
* **mcp_capability_core:** rewrite tap_widget handler to use CommandRunner ([f0c2ccf](https://github.com/Arenukvern/mcp_flutter/commit/f0c2ccf5df49884831a1d4269daf33345bb6642c))
* **mcp_capability_kernel:** add CommandRunner HostService interface ([c8cd135](https://github.com/Arenukvern/mcp_flutter/commit/c8cd1355312071a7290ca67364b380ce98b7df55))
* **mcp_server_dart:** wire DefaultCommandRunner into McpHost; migrate type files to re-export mcp_shared_core ([e2d6f48](https://github.com/Arenukvern/mcp_flutter/commit/e2d6f4826ffa42763688bbedcdb7b65afaa90a46))
* **mcp_shared_core:** scaffold pure-Dart package with CoreCommand hierarchy and value types ([24bb65c](https://github.com/Arenukvern/mcp_flutter/commit/24bb65c52c0e01ca25e09e55dfc706638720a957))
* **mcp_toolkit:** expose isSelected flag in semantic snapshot nodes ([64a35af](https://github.com/Arenukvern/mcp_flutter/commit/64a35afaec15b4e58d95bbbaa43a6be1d62fc092))
* **mcp_toolkit:** pump frames manually while the host window is backgrounded ([729519e](https://github.com/Arenukvern/mcp_flutter/commit/729519ecd1eb336efc3efc48a1ec06fa92e809bf))
* **mcp_toolkit:** pump frames manually while the host window is backgrounded. Contributed by https://github.com/dipsy (thank you!) ([8264cde](https://github.com/Arenukvern/mcp_flutter/commit/8264cded0156e4468bb4a2be26dac362b51e3c42))
* **mcp:** harden boundary validation across agentkit and gateways ([2e00439](https://github.com/Arenukvern/mcp_flutter/commit/2e00439db0b6a9823e847809e27139a37c8c08e6))
* **p1:** handle_dialog (dismiss) tool ([5832b93](https://github.com/Arenukvern/mcp_flutter/commit/5832b93e47269847b4f4aa10281892f1480382c8))
* **p1:** MCPToolkitBinding.setNavigatorKey opt-in API ([822f376](https://github.com/Arenukvern/mcp_flutter/commit/822f376111f7d14119e5c1d6507a8ee3c0f0abcd))
* **p1:** navigate tool (push/pop/popUntil) ([4f63d74](https://github.com/Arenukvern/mcp_flutter/commit/4f63d7401948c1d89cff3e2b3a6d067cf245c1ef))
* **p1:** press_key tool + ControlFlowService ([9b5009b](https://github.com/Arenukvern/mcp_flutter/commit/9b5009b3d8f4056831ef3e33c8a2685fcabb303a))
* **p1:** scaffold press_key, handle_dialog, navigate commands ([fe13ceb](https://github.com/Arenukvern/mcp_flutter/commit/fe13cebdff6afaef82778fd733e71f64b61f6286))
* **p1:** server executors + handlers + registrations ([0fe69db](https://github.com/Arenukvern/mcp_flutter/commit/0fe69dbc0cafda06e90b681c3146c40256dd6db1))
* **p2:** hover tool via PointerHoverEvent ([e798554](https://github.com/Arenukvern/mcp_flutter/commit/e7985547d74f7f9fa68e658caa2767c08f313103))
* **p2:** scaffold fill_form and hover commands ([a031e2e](https://github.com/Arenukvern/mcp_flutter/commit/a031e2e9fc8b1e18246b0affba8048b08b30ef4c))
* **p2:** server executors + handlers + registrations ([daf27e6](https://github.com/Arenukvern/mcp_flutter/commit/daf27e6f05befb3cb738a1f2b8adc4c9ddaff0cb))
* **plugin:** add Codex plugin manifest ([d389604](https://github.com/Arenukvern/mcp_flutter/commit/d38960408be340c386cbd6386feecbc1ffb3814b))
* **plugin:** add Cursor plugin manifest ([f1f9322](https://github.com/Arenukvern/mcp_flutter/commit/f1f93224db17dfc813866432d6f3f42cdc345a1a))
* **plugin:** add MCP server config for Cursor + Codex ([1c4b8b9](https://github.com/Arenukvern/mcp_flutter/commit/1c4b8b909e700ed7f15e0e720b52d37cea94fd2c))
* **plugin:** revise setup skill for post-v3.0.0 surface ([620a58e](https://github.com/Arenukvern/mcp_flutter/commit/620a58e4c95cc0a6ac77f78a0fb6f25c761e8d5b))
* **plugin:** scaffold 5 skill files with frontmatter ([95bf869](https://github.com/Arenukvern/mcp_flutter/commit/95bf869db6e0ad5f07f90832d9c2663e1bb27c39))
* **plugin:** write control skill body ([bfec8d9](https://github.com/Arenukvern/mcp_flutter/commit/bfec8d9948d7c566d307270f2bd24f6ce611214a))
* **plugin:** write debug skill body ([b7be59e](https://github.com/Arenukvern/mcp_flutter/commit/b7be59ecb703c30e386c815512eba82b5daedeec))
* **plugin:** write guide skill body ([49bee46](https://github.com/Arenukvern/mcp_flutter/commit/49bee4687906a6adf6507f9b11c05c63b4c9b80d))
* **plugin:** write inspect skill body ([2e2b132](https://github.com/Arenukvern/mcp_flutter/commit/2e2b13252273de4ac3cd09a0311c83b2022a6d8b))
* **plugin:** write setup skill body ([9cd8a85](https://github.com/Arenukvern/mcp_flutter/commit/9cd8a855ea5c9172d7d70dd7815eee991447d424))
* **promo:** consolidate promo branch work ([eca2764](https://github.com/Arenukvern/mcp_flutter/commit/eca27649a9bae41e990844575feab5b699f85a03))
* promote hosted dependency steward gate ([82868e8](https://github.com/Arenukvern/mcp_flutter/commit/82868e83145fd9c56dbd45f677c42ea39b60e4ce))
* **server:** flip --use-capability-kernel default to on (the cut) ([849c812](https://github.com/Arenukvern/mcp_flutter/commit/849c8121711f7b9ee8f87f9d2f9fc6f57671d8c8))
* **server:** McpHost capability registrar with prefix + collision enforcement ([2098282](https://github.com/Arenukvern/mcp_flutter/commit/2098282756016b08052877c85974ad14633e5094))
* **server:** wire --use-capability-kernel flag with McpHost dispatch (default off) ([44b476b](https://github.com/Arenukvern/mcp_flutter/commit/44b476b2ca3158c1c56edb60d54c1929906dd20d))
* **server:** wire CoreCapability into server binary via capability kernel flag ([0f577c1](https://github.com/Arenukvern/mcp_flutter/commit/0f577c152e7d586d43d12d892676d73d4a430c21))
* **server:** wire kernel dispatch bridge + gate legacy tools on !flag ([ae9139a](https://github.com/Arenukvern/mcp_flutter/commit/ae9139a18b2154b0fb2304bcf98375c8fb8dcd7b))
* **shared_core:** add CoreResult.toErrorEnvelopeJson + tests (I1) ([9d5b489](https://github.com/Arenukvern/mcp_flutter/commit/9d5b48980ff5a4050524c333c977f8184eb332a1))
* **skill_assets:** bundle skill bodies into mcp_server_dart ([e41bc77](https://github.com/Arenukvern/mcp_flutter/commit/e41bc778859effbf2aaab329e28ded9873ddda9a))
* **wait_for:** expose via interaction_toolkit MCP entry ([2c541da](https://github.com/Arenukvern/mcp_flutter/commit/2c541daed48674ac2875b1dd44476273aaa44e99))
* **wait_for:** noText predicate ([06e48ce](https://github.com/Arenukvern/mcp_flutter/commit/06e48ce606f017ca1c149aa002f803bbd52027b2))
* **wait_for:** register command + error codes (no behavior) ([3383168](https://github.com/Arenukvern/mcp_flutter/commit/338316809ca89454ed274f0ddb28afb028a3afe9))
* **wait_for:** server executor + handler + tool registration ([f44c03a](https://github.com/Arenukvern/mcp_flutter/commit/f44c03a672a884ea9b2ea1144ac1e03089f32e80))
* **wait_for:** stable predicate ([98f85d6](https://github.com/Arenukvern/mcp_flutter/commit/98f85d6ad4bfa55afe1c07a3f3be77d445cff52a))
* **wait_for:** text predicate + peekSemanticSnapshot ([e0350ce](https://github.com/Arenukvern/mcp_flutter/commit/e0350ce74ac593da87752fa7b42c5d266d15be6e))
* **wait_for:** WaitPredicateService time predicate ([5a6b222](https://github.com/Arenukvern/mcp_flutter/commit/5a6b2223300071e575138a60894e7988638aeb90))
* **wait:** add a node predicate to wait_for ([f20b712](https://github.com/Arenukvern/mcp_flutter/commit/f20b712c79cf040e11bfcc1e33c60aabe183fd24))
* **wait:** add a node predicate to wait_for. Made by [@dipsy](https://github.com/dipsy)  https://github.com/Arenukvern/mcp_flutter/pull/121 ([cb749d7](https://github.com/Arenukvern/mcp_flutter/commit/cb749d798df0fd6741beac53e33afd06fd0c4cce))
* web CDP capture and cross-platform platform view showcase ([3771315](https://github.com/Arenukvern/mcp_flutter/commit/377131564a1fd45a311806bdc23ba6cf3f91a25f))


### Bug Fixes

* add FMT_MODE_PRELUDE to boundary-audit skill and sync assets ([81f788c](https://github.com/Arenukvern/mcp_flutter/commit/81f788cbaafde6ff70105e106eed0b55edfa2061))
* add missing closing parenthesis in dynamic tools registration ([72f4c90](https://github.com/Arenukvern/mcp_flutter/commit/72f4c9075322a35b9388251d2182ac31bac85724))
* **agentkit:** align fmt tool docs and tests after Phase 6g ([059e501](https://github.com/Arenukvern/mcp_flutter/commit/059e501bb0f47e4428de7065ad797f70994dc83c))
* **agentkit:** drop path dep on flutter_mcp_toolkit_core for publish ([32d6307](https://github.com/Arenukvern/mcp_flutter/commit/32d63071077e21f7f59b447e571a262094377d24))
* **agentkit:** restore dynamic registry VM guard imports ([91762e5](https://github.com/Arenukvern/mcp_flutter/commit/91762e529389b754d871ff3259e39efe6bf2ee0d))
* **agentkit:** restore xsoulspace_lints dependency in pubspec.yaml files ([4f398fc](https://github.com/Arenukvern/mcp_flutter/commit/4f398fcc56de1a6c4852d9bc0be9d738b697abf6))
* agents ([2124310](https://github.com/Arenukvern/mcp_flutter/commit/21243107eeb5ba18560b9bc27308e3c7afc61de5))
* agetn ([08e3c29](https://github.com/Arenukvern/mcp_flutter/commit/08e3c29ceea51e5611b67428ca830d88f2d45b11))
* align release checks with Flutter SDK pins ([175ca58](https://github.com/Arenukvern/mcp_flutter/commit/175ca5875591eca6238f2326bd3a450338827f99))
* **capability_core:** align scroll/swipe schemas with legacy (number distance, no direction enum) ([f9e264d](https://github.com/Arenukvern/mcp_flutter/commit/f9e264d19f2eb0509ead581ba66a2c049d6ea754))
* changelog ([fbdcf74](https://github.com/Arenukvern/mcp_flutter/commit/fbdcf74e68132476b47dcceabfd5d1655ef3fbca))
* **cli:** clean StateError handling for init auto-detect; rename serverInfo to flutter-mcp-toolkit-server ([34f5a8c](https://github.com/Arenukvern/mcp_flutter/commit/34f5a8c35dbc554a3caf5dea76a5a7c6d4140bee))
* **cli:** validate-runtime flutter_layer fallback with platform views ([d69eeaf](https://github.com/Arenukvern/mcp_flutter/commit/d69eeaf4e2eedaf283827deb901f33150f301b9b))
* **codegen-init:** add correct pubspec dependency ([dbbb32d](https://github.com/Arenukvern/mcp_flutter/commit/dbbb32d904dd9e8613b6c5236b3e5bf645f2724c))
* **codegen-init:** add correct pubspec dependency ([0fb5230](https://github.com/Arenukvern/mcp_flutter/commit/0fb52307df316d06a8074c46e51027ea7ad9cda9))
* **codegen-init:** use published mcp_toolkit package name ([9d46ba3](https://github.com/Arenukvern/mcp_flutter/commit/9d46ba3c4221f3d6157d6b5568faac51365645d6))
* **codegen-init:** use published mcp_toolkit package name ([#1](https://github.com/Arenukvern/mcp_flutter/issues/1)) ([a53a908](https://github.com/Arenukvern/mcp_flutter/commit/a53a908320ff1ba3e0b117f29ba3f0c7f0bf5bd3))
* **contracts:** point error_code_playbook checker at mcp_shared_core ([c4df607](https://github.com/Arenukvern/mcp_flutter/commit/c4df6078b0566847a3d94745c4cdb19966784377))
* **contracts:** repair error_code_playbook check path + backfill playbook ([a0e2d4b](https://github.com/Arenukvern/mcp_flutter/commit/a0e2d4bb2de9ca414ad07036cdcfed437acee5c6))
* dart ([2e5568d](https://github.com/Arenukvern/mcp_flutter/commit/2e5568dd1c47cd95457b1c3794a105d08049ffe4))
* deps ([5ac04bc](https://github.com/Arenukvern/mcp_flutter/commit/5ac04bc85f4d2f1a5e6a200cb007a4e39662bf79))
* docs ([468a76e](https://github.com/Arenukvern/mcp_flutter/commit/468a76e457df6f0012582364b42500d96df25030))
* docs ([890b2b9](https://github.com/Arenukvern/mcp_flutter/commit/890b2b99d73481c0203696671ea3904af51ae6d3))
* **docs:** release 3.0.4 — docs.page branding and SEO ([4fc98cc](https://github.com/Arenukvern/mcp_flutter/commit/4fc98ccb05941bb9ae5894eed570b8e59b653ac7))
* errors summarization ([9252699](https://github.com/Arenukvern/mcp_flutter/commit/925269926eee7c949a9630efe71ef1f1621c6b34))
* format ([1da5f5d](https://github.com/Arenukvern/mcp_flutter/commit/1da5f5d3d6742d952332b5f65af6204c9aa4bc8a))
* formatting ([35a7e94](https://github.com/Arenukvern/mcp_flutter/commit/35a7e94d34cd35cdb0f71a10c5e4ff19fb2544b6))
* **gestures:** keep synthetic pointers off the platform mouse device ([4fe9886](https://github.com/Arenukvern/mcp_flutter/commit/4fe9886049cd7c6af890c58b64d3940fad0b4475))
* **gestures:** keep synthetic pointers off the platform mouse device. Made by [@dipsy](https://github.com/dipsy) https://github.com/Arenukvern/mcp_flutter/pull/120 ([9fc64e9](https://github.com/Arenukvern/mcp_flutter/commit/9fc64e95e348aef329762c72ed294abdda5a8596))
* **gestures:** release the synthetic device after a scroll too ([62a96e9](https://github.com/Arenukvern/mcp_flutter/commit/62a96e9ba80968df2dd4a6ab5a90e85549f12a20))
* https://github.com/drown0315 broken link ([48fe450](https://github.com/Arenukvern/mcp_flutter/commit/48fe4509f5b1ab47e2f7ae588c467ea01b57f85d))
* json ([c67e8fe](https://github.com/Arenukvern/mcp_flutter/commit/c67e8fe5773c9a5da94e018c1dbc507556e6cce1))
* **kernel:** code review fixes (final params, config tests, barrel imports, immutable) ([981a2ff](https://github.com/Arenukvern/mcp_flutter/commit/981a2ff4db6f25ae9fbf4cfccf51d81474830928))
* lints ([288ce18](https://github.com/Arenukvern/mcp_flutter/commit/288ce184b331e6ba2dab2a29b011c0b40619e9d8))
* lints ([8e2ea60](https://github.com/Arenukvern/mcp_flutter/commit/8e2ea6073b51e19b4c12b5d7a796fdf7bb93a902))
* live edit ([5facbd7](https://github.com/Arenukvern/mcp_flutter/commit/5facbd73a5ff09396581f6c29d28d3177739bf2b))
* **mcp_toolkit:** don't double-dispatch tap on desktop when semantic action succeeds ([ab6fc27](https://github.com/Arenukvern/mcp_flutter/commit/ab6fc27239a5c92d527d1ce7582c00d0454c2572))
* **mcp_toolkit:** preserve mid-frame microtask phase in suspended pump ([3d6ee73](https://github.com/Arenukvern/mcp_flutter/commit/3d6ee738c61d25748879d7dc81aa270af19c0f6c))
* **mcp_toolkit:** tap double-dispatch on desktop + expose isSelected in semantic snapshot ([af2da1a](https://github.com/Arenukvern/mcp_flutter/commit/af2da1a744953ad7188548ac9cf445a485f83d26))
* **mcp_toolkit:** VM isolateId causes tool validation error ([37fcaa8](https://github.com/Arenukvern/mcp_flutter/commit/37fcaa8442f6ffed6d236ff6e40a0fec1381c6cc))
* **mcp-registry:** address PR 123 review comments ([7866c28](https://github.com/Arenukvern/mcp_flutter/commit/7866c289211fda25a5c3643eb0334c9da14b6769))
* mdc ([7fa2976](https://github.com/Arenukvern/mcp_flutter/commit/7fa297659f6f8278bc5ffdec07fac9d769ba57c0))
* **p2:** fill_form actually stops on first toolkit-side failure ([4173a74](https://github.com/Arenukvern/mcp_flutter/commit/4173a7475417667c9433a7e54f5677913edd8628))
* perf changelog ([7eef42e](https://github.com/Arenukvern/mcp_flutter/commit/7eef42e3e6747dd10875748f960e0540e6a2bcd8))
* plugin ([85e8f78](https://github.com/Arenukvern/mcp_flutter/commit/85e8f7807df70df4f8d3e4214c3a580735e37829))
* promo ([54d981c](https://github.com/Arenukvern/mcp_flutter/commit/54d981c2192e308c645faa5fcd09cfda2a9e6bfc))
* pub.dev ([5a17df2](https://github.com/Arenukvern/mcp_flutter/commit/5a17df28325f4dd99c86afd69c1a1d9c0eaa47bb))
* pubspec ([bb8f573](https://github.com/Arenukvern/mcp_flutter/commit/bb8f573c6dec72272ca5e5576d204b840ea6291d))
* readme ([b95e8b3](https://github.com/Arenukvern/mcp_flutter/commit/b95e8b3d25c5529e21c79a3b06ebd97524573671))
* readme ([0aa1c00](https://github.com/Arenukvern/mcp_flutter/commit/0aa1c001946aad1cbf807113cb89cb5740f0e347))
* **release:** bump Dockerfile SDK pin to dart:3.11.0-sdk ([887f88f](https://github.com/Arenukvern/mcp_flutter/commit/887f88fd64c9a494e94ade19685705ee389493f2))
* **release:** exercise release token for 4.0.0-dev.3 ([142e2b4](https://github.com/Arenukvern/mcp_flutter/commit/142e2b4bb2677b19d0c8859e11907a3fac1bcc44))
* **release:** include package changelogs in release sync ([cd7dbfd](https://github.com/Arenukvern/mcp_flutter/commit/cd7dbfdf646cbf97e8e1bdc2b68d9589527efd72))
* **release:** ship macOS binaries for Apple Silicon only ([b0d3422](https://github.com/Arenukvern/mcp_flutter/commit/b0d34226899681f366fc61e039bd30ea021899a5))
* **release:** sync generated release touchpoints ([a552b30](https://github.com/Arenukvern/mcp_flutter/commit/a552b30bfed80df5309a003e47750fb22cc08d21))
* **release:** sync package changelogs for pub publish ([6dfca08](https://github.com/Arenukvern/mcp_flutter/commit/6dfca082e1b1472d2913887c93fb54b908eb9e6b))
* **server:** address PR [#115](https://github.com/Arenukvern/mcp_flutter/issues/115) review comments ([d2cea26](https://github.com/Arenukvern/mcp_flutter/commit/d2cea2613a4504cf2ae470b683adde2c0d6d9bd4))
* **server:** address PR 115 review comments ([7f140dc](https://github.com/Arenukvern/mcp_flutter/commit/7f140dcfb744b8bca13b24b3c25032345accfbe0))
* **server:** clean up Windows machine discovery process trees ([11d5d02](https://github.com/Arenukvern/mcp_flutter/commit/11d5d02b3e6066820720285bfd369336d127e4e8))
* **server:** clean up Windows machine discovery process trees. Made by [@wenyue](https://github.com/wenyue) in https://github.com/Arenukvern/mcp_flutter/pull/115 ([b510de0](https://github.com/Arenukvern/mcp_flutter/commit/b510de08d14cc11dab3b8bea04503a9bbae81e9e))
* **server:** complete host_flag_smoke_test deletion + tighten catch clauses ([27a81a4](https://github.com/Arenukvern/mcp_flutter/commit/27a81a46e4f5bf4642afee1710985f4f6f90937e))
* **server:** handle already-exited root in Windows tree terminator ([aa076e7](https://github.com/Arenukvern/mcp_flutter/commit/aa076e7ce4a93b14ab54fc2432964508d3c449c6))
* **server:** harden Windows machine discovery cleanup ([4810a33](https://github.com/Arenukvern/mcp_flutter/commit/4810a33a7c433949b7f59c994b9a43930da32768))
* **server:** return capture_ui_snapshot images as ImageContent ([043dc7a](https://github.com/Arenukvern/mcp_flutter/commit/043dc7afaf9c3c66c5abd2b14b9de641fde03368))
* **server:** return capture_ui_snapshot images as ImageContent. Made by https://github.com/dipsy ([3667891](https://github.com/Arenukvern/mcp_flutter/commit/3667891a82bebc480b627f7f7641ee2bee40b219))
* **server:** T2 review fixes (seal tests, partial-state rollback, dispose isolation, doc updates) ([b45a706](https://github.com/Arenukvern/mcp_flutter/commit/b45a7069b1e89d6f26ace54806c11132cce53b6a))
* **server:** update tools/list assertions for prefixed names (post-cut) ([4103744](https://github.com/Arenukvern/mcp_flutter/commit/410374451a5752b77d26a434d5d03984806531c6))
* shared cor ([baaf163](https://github.com/Arenukvern/mcp_flutter/commit/baaf163fbea97af75d18e1baeb3b1248404cc08c))
* sync skill_assets.g.dart after 3.0.4 plugin bump ([a618201](https://github.com/Arenukvern/mcp_flutter/commit/a618201e299403f724015f7e0d179746cbe4bbad))
* **tool:** detect repo root from a linked worktree in build_skill_assets ([87c5cc8](https://github.com/Arenukvern/mcp_flutter/commit/87c5cc880bbe2272f7f1dbcdd5a284a1962c4c72))
* **tool:** detect repo root from a linked worktree in build_skill_assets ([3ea5433](https://github.com/Arenukvern/mcp_flutter/commit/3ea54336d2132b6fa09a1096e75a425c6503960b))
* **toolkit:** resolveCenter/resolveBounds return logical (not physical) coords ([340e729](https://github.com/Arenukvern/mcp_flutter/commit/340e7299f41f137a971c5b30b623268aa8e26499))
* use deterministic dogfood tracker merge ([3e07d3a](https://github.com/Arenukvern/mcp_flutter/commit/3e07d3a5baffdb2afdd14f052d718d2cace0ab70))


### Documentation

* add agentkit architecture design spec ([371aa16](https://github.com/Arenukvern/mcp_flutter/commit/371aa16135ca12c8a4793a18e4628a7bf2cfd46f))
* add agentkit Phase 1 implementation plan ([f56c83a](https://github.com/Arenukvern/mcp_flutter/commit/f56c83aa966962cd69e82c8039f11d9d60bd94cb))
* Add Ask DeepWiki badge to README ([6975f88](https://github.com/Arenukvern/mcp_flutter/commit/6975f88acf033d14c17213c532af2fd441c8f2b0))
* add chrstphe as a contributor for doc, and platform ([9b6fd6b](https://github.com/Arenukvern/mcp_flutter/commit/9b6fd6b17e6ec869b4197d07792086b710fa7b15))
* add CONTRIBUTING maintainer section for binary releases ([2c93235](https://github.com/Arenukvern/mcp_flutter/commit/2c932358d6572d3c0a86b17b6bdbcbbe7528a86a))
* add dipsy as a contributor for code, and maintenance ([fea5eab](https://github.com/Arenukvern/mcp_flutter/commit/fea5eabe561479516f3e240220b8fdff5abbdf98))
* add dipsy as a contributor for code, maintenance, and bug ([99d669e](https://github.com/Arenukvern/mcp_flutter/commit/99d669e8b580a698bee8fca0ac87d4eb1beba460))
* add drown0315 as a contributor for code, maintenance, and bug ([192cba5](https://github.com/Arenukvern/mcp_flutter/commit/192cba5917dd9143e74b7f4f9da7a9fce7f22acf))
* add druyang as a contributor for code, maintenance, and bug ([3da354e](https://github.com/Arenukvern/mcp_flutter/commit/3da354e40b24879efc78a1a3e6803845e5da0909))
* add tekboxs as a contributor for code, and maintenance ([0cab8cd](https://github.com/Arenukvern/mcp_flutter/commit/0cab8cd746bb922a11e361491228d54a4031f1ba))
* add v2 → v3 migration guide ([d514710](https://github.com/Arenukvern/mcp_flutter/commit/d51471015b1d314ab19bc4e2392d17ac88a05bdb))
* add v3.0.0 spec + 4 implementation plans ([c7c94aa](https://github.com/Arenukvern/mcp_flutter/commit/c7c94aa341b3d3f8f976b34a7fd2496266cc1b1d))
* add wenyue as a contributor for code, and maintenance ([41fc0e6](https://github.com/Arenukvern/mcp_flutter/commit/41fc0e6d68eb95e5c71b1486a336721486e2f00f))
* **agentkit:** add ecsly client DX patterns to spec and plan ([f2a56da](https://github.com/Arenukvern/mcp_flutter/commit/f2a56dabfe48b10e66e377a5faff735d50542c1f))
* **agentkit:** add phase6 pre-extract row to tracker ([5578777](https://github.com/Arenukvern/mcp_flutter/commit/55787774de06b9e3b46f760ac82050bc67c5c7bc))
* **agentkit:** add self-closing implementer/closer loop ([0ff6f44](https://github.com/Arenukvern/mcp_flutter/commit/0ff6f443910148fbbd5849a41bf2f31fae6e12aa))
* **agentkit:** align tracker and rollout after phase 4 ([c4d61ba](https://github.com/Arenukvern/mcp_flutter/commit/c4d61baeb40d9655feb06b59c8f7799a7487872f))
* **agentkit:** archive phase plans and refresh rollout for phase 6. ([a269a26](https://github.com/Arenukvern/mcp_flutter/commit/a269a264bb2435d3ad3c82a8390b214990a78906))
* **agentkit:** drop engineering-loop from self-closing loop ([3ba7916](https://github.com/Arenukvern/mcp_flutter/commit/3ba791677fdd41afdb9b7054393e699da074bbe4))
* **agentkit:** Phase 6 Bar D spec and implementation plan. ([eb30405](https://github.com/Arenukvern/mcp_flutter/commit/eb30405d87f86fe5162eda78f2fb1151c24c0bb4))
* **agentkit:** Phase 6 platform scope — Web C, skip HarmonyOS. ([a86c513](https://github.com/Arenukvern/mcp_flutter/commit/a86c5137e8c91ac9d79e7d8770182fe15e5e8d23))
* **agentkit:** Phase 6g skills and skill_assets for AgentCallEntry ([893ffee](https://github.com/Arenukvern/mcp_flutter/commit/893ffeec170aca822ce1565ff0966a0fa059ab03))
* **agentkit:** Phase 6h complete_in_repo gate and closure ([910d182](https://github.com/Arenukvern/mcp_flutter/commit/910d1822a176fede4cb6e37c4a213570a157cb30))
* **agentkit:** split descriptor vs RegisteredAgentIntent ([2aafb7e](https://github.com/Arenukvern/mcp_flutter/commit/2aafb7e49d08ff9b165f8d62cf46440a628b9f65))
* **ai_agents:** redirect execution_playbook to plugin skills ([a6be2dc](https://github.com/Arenukvern/mcp_flutter/commit/a6be2dcd7bba52bc5c97b9d24e892f11eda85f9f))
* **ai_agents:** rewrite overview around the plugin ([28c6c9d](https://github.com/Arenukvern/mcp_flutter/commit/28c6c9db5c00f21364d1981c05e22e9cdf5048d0))
* append steward cascading governance instructions ([880bfa4](https://github.com/Arenukvern/mcp_flutter/commit/880bfa4a7f80fab4e94ed7afb07a74f6224df9c8))
* architecture cleanup, intentcall, flutter mcp toolkit purpose ([b1609bf](https://github.com/Arenukvern/mcp_flutter/commit/b1609bff17ad95d5b1b2a04271640b44d935c2d8))
* **changelog:** document v3.0.0 capability-prefix breaking change ([dee690e](https://github.com/Arenukvern/mcp_flutter/commit/dee690e8ad5c8f6392ecedc1bfc55d8cb5964777))
* **code:** update lingering core_ tool-name references in code comments ([fe5cece](https://github.com/Arenukvern/mcp_flutter/commit/fe5cece8006cd6ca4870c0473e546213650853b5))
* **contributing:** add section on editing skills ([26e2e2a](https://github.com/Arenukvern/mcp_flutter/commit/26e2e2ab973c87691e34ab235560522499018f58))
* **core:** document DragPointerKind members and parser contract ([a834cdb](https://github.com/Arenukvern/mcp_flutter/commit/a834cdb657d7b26955594e50652cc72d5e6bfbfa))
* **core:** remove built_in_tools + error_code_playbook (migrated to skills) ([4c96a83](https://github.com/Arenukvern/mcp_flutter/commit/4c96a83f11cf932f8b9deb8dc329c3e547bc7724))
* **mcp_server_dart:** update CHANGELOG + README for v3.0.0 names ([f3842d1](https://github.com/Arenukvern/mcp_flutter/commit/f3842d1c1dce4c18010f13606a3c92ceb2176cb4))
* **mcp_toolkit:** update README for AgentCallEntry API ([5fda437](https://github.com/Arenukvern/mcp_flutter/commit/5fda43796519e93da587decc858289ef9757973b))
* **p1:** mark P1 shipped in roadmap ([3ed54d1](https://github.com/Arenukvern/mcp_flutter/commit/3ed54d18c6a3a7bffd1cc2d167d89cc423328854))
* **p2:** close audit gap matrix + persist DPR bug as todo ([94b98ca](https://github.com/Arenukvern/mcp_flutter/commit/94b98ca48d5a71e3136dd4dc59a0a419c58675e4))
* **p2:** mark P2 shipped, note select_option deferral in audit ([465d172](https://github.com/Arenukvern/mcp_flutter/commit/465d1725bcccd75d4516720eeb869d6b875cc696))
* **p3:** defer network introspection — move spec to todo/ ([7a49850](https://github.com/Arenukvern/mcp_flutter/commit/7a4985094651cb2c8cefd68a2839d249ab0a3c40))
* **p3:** network introspection design ([48248b3](https://github.com/Arenukvern/mcp_flutter/commit/48248b34a89b960ac0c2fac896c3f1bc67894d89))
* **p4:** consolidation research — defer set A/C, drop set B from candidates ([2cc95e0](https://github.com/Arenukvern/mcp_flutter/commit/2cc95e05ece02b328e0a3d895cbd1ab940c1a330))
* persist steward proof summaries ([339b20f](https://github.com/Arenukvern/mcp_flutter/commit/339b20f9ad6b9aea6856016aa1ce137b7150e89b))
* **plan:** scope down v3.0.0 — defer live_edit to post-release ([afc06ba](https://github.com/Arenukvern/mcp_flutter/commit/afc06bab74acacccb6d71dc7171543a79f8d6673))
* **plugin:** add plugin source README ([3e2ef37](https://github.com/Arenukvern/mcp_flutter/commit/3e2ef3708275744f59c35e8882068b88c90b915b))
* **plugin:** update flutter-mcp plugin surfaces for core_* tool names ([a6251f7](https://github.com/Arenukvern/mcp_flutter/commit/a6251f7b5fc84624abb00f8b3ff109237233d9b4))
* prepare runtime text input steward proof ([87c493c](https://github.com/Arenukvern/mcp_flutter/commit/87c493c8fb880c58572aa7b59d74e368a68b5144))
* **readme:** rewrite hero around the four-step install ([14c8fb2](https://github.com/Arenukvern/mcp_flutter/commit/14c8fb2f9cd6d71992da23fb6620ae8745ef06a5))
* record bounded steward h5 adoption ([bf21f6f](https://github.com/Arenukvern/mcp_flutter/commit/bf21f6f1b0648f0fdcb0d97c84ab3174a0c23701))
* record steward adoption evidence ([fd0c059](https://github.com/Arenukvern/mcp_flutter/commit/fd0c0597d0a7c57e3643a0cc423926ca4fbc5f96))
* refresh direct steward proof summaries ([638b970](https://github.com/Arenukvern/mcp_flutter/commit/638b970b538484f36ba27f77a08bb396b8e08255))
* refresh steward h5 proof summary ([d74a524](https://github.com/Arenukvern/mcp_flutter/commit/d74a5247b4602f2a49bd0e33dcb4fd593f1825d0))
* remove deleted-page entries from navigation ([1703a92](https://github.com/Arenukvern/mcp_flutter/commit/1703a924df1a77e6ae9e65d1e05acebafdebcaef))
* remove manual install/client-setup docs (superseded by install.sh + init) ([f4bc18d](https://github.com/Arenukvern/mcp_flutter/commit/f4bc18dc3ea079d4418aa77cba06ccc0327b0b25))
* remove per-agent setup docs (superseded by 'flutter-mcp-toolkit init &lt;agent&gt;') ([200834b](https://github.com/Arenukvern/mcp_flutter/commit/200834b873279f39d14257b3d5fde9610780116e))
* **server:** document --use-capability-kernel requirement on McpHost services (I3) ([ae71960](https://github.com/Arenukvern/mcp_flutter/commit/ae7196003a04a48be913c437d914e21661c6354e))
* **start_here:** refresh migration_v2_to_v3 for v3.0.0 names ([bb8c74f](https://github.com/Arenukvern/mcp_flutter/commit/bb8c74f271127ca5ea99b68a0120d9a8476fc345))
* **start_here:** refresh names + reference init command ([5b48c5c](https://github.com/Arenukvern/mcp_flutter/commit/5b48c5c4e89fda5f878bdde7f1bb024649896cbb))
* **start_here:** replace step 1 with four-step install ([ca73616](https://github.com/Arenukvern/mcp_flutter/commit/ca73616dc4c1d33b5c5dc010f9948cb78424236e))
* update .all-contributorsrc ([35101e0](https://github.com/Arenukvern/mcp_flutter/commit/35101e0fd70e7e0902a61723ff0502bdff9c1078))
* update .all-contributorsrc ([1ccbbce](https://github.com/Arenukvern/mcp_flutter/commit/1ccbbcecb7dd26e92f559cd49da8eceefd88cc95))
* update .all-contributorsrc ([57e2178](https://github.com/Arenukvern/mcp_flutter/commit/57e2178666998d5db6d5758e860b026efc094816))
* update .all-contributorsrc ([1f670f2](https://github.com/Arenukvern/mcp_flutter/commit/1f670f2d17ca1e554d3774f707525ca2dee498d6))
* update .all-contributorsrc ([a24a9ff](https://github.com/Arenukvern/mcp_flutter/commit/a24a9ff0efec6eb9c5a27098913a1245db860a40))
* update .all-contributorsrc ([33c1495](https://github.com/Arenukvern/mcp_flutter/commit/33c1495584bf69603ea4521bb6ad3c32d6dd1157))
* update .all-contributorsrc ([2bfae74](https://github.com/Arenukvern/mcp_flutter/commit/2bfae7414ac8836cf779386b949bd9f590198228))
* update CLAUDE.md + ARCHITECTURE.md for v3.0.0 names ([465d7c9](https://github.com/Arenukvern/mcp_flutter/commit/465d7c91eb198506ea134d8f7daf768c813fa9a0))
* update GitNexus project details and enhance harness engineering lifecycle documentation ([9245d8f](https://github.com/Arenukvern/mcp_flutter/commit/9245d8fa2d7d1789b7d5cf4cf3392834877e8774))
* update README.md ([3d4399f](https://github.com/Arenukvern/mcp_flutter/commit/3d4399f0b8c83f773267ecfacd0cafadc1cfd219))
* update README.md ([c055f5a](https://github.com/Arenukvern/mcp_flutter/commit/c055f5afcd198a851c6b3d7a43901d2d289416c7))
* update README.md ([a15e2bc](https://github.com/Arenukvern/mcp_flutter/commit/a15e2bc87cbb5a01196ef1162db4e6291c47593c))
* update README.md ([d078171](https://github.com/Arenukvern/mcp_flutter/commit/d078171e8c50aebeb3d1572474ce1a83b0e19400))
* update README.md ([54bbf4d](https://github.com/Arenukvern/mcp_flutter/commit/54bbf4d6aaaf904fa6316987c2010550dc1f776d))
* update README.md ([52fd2d5](https://github.com/Arenukvern/mcp_flutter/commit/52fd2d5a79e56740a8556655969c62fb89f813eb))
* update README.md ([faf051e](https://github.com/Arenukvern/mcp_flutter/commit/faf051eb2d4d3cff69c4da2de492f2bc421a9c89))
* update repo docs for v3.0.0 capability-kernel cut ([d08ce16](https://github.com/Arenukvern/mcp_flutter/commit/d08ce16f289a087a8f8f4f8f2e1b8b770a600a1c))
* update star history chart to README ([46e5d89](https://github.com/Arenukvern/mcp_flutter/commit/46e5d8998055c75466d2b3b167abbc7e0fac5516))
* update video walkthroughs with improved titles and punctuation ([7c47074](https://github.com/Arenukvern/mcp_flutter/commit/7c47074b27a55cdd1f67a5c6b99a7085d7927801))
* **wait_for:** mark P0 shipped in roadmap ([db5fa06](https://github.com/Arenukvern/mcp_flutter/commit/db5fa06fd05007a0781afbf2950d807d48ce3864))

## [Unreleased]

### Bug Fixes

* **server:** coalesce identical overlapping Flutter discovery requests and terminate their process trees on Windows

## [4.0.0-dev.8](https://github.com/Arenukvern/mcp_flutter/compare/v4.0.0-dev.7...v4.0.0-dev.8) (2026-07-31)


### Features

* **mcp_toolkit:** pump frames manually while the host window is backgrounded ([729519e](https://github.com/Arenukvern/mcp_flutter/commit/729519ecd1eb336efc3efc48a1ec06fa92e809bf))
* **mcp_toolkit:** pump frames manually while the host window is backgrounded. Contributed by https://github.com/dipsy (thank you!) ([8264cde](https://github.com/Arenukvern/mcp_flutter/commit/8264cded0156e4468bb4a2be26dac362b51e3c42))


### Bug Fixes

* **mcp_toolkit:** preserve mid-frame microtask phase in suspended pump ([3d6ee73](https://github.com/Arenukvern/mcp_flutter/commit/3d6ee738c61d25748879d7dc81aa270af19c0f6c))
* **server:** return capture_ui_snapshot images as ImageContent ([043dc7a](https://github.com/Arenukvern/mcp_flutter/commit/043dc7afaf9c3c66c5abd2b14b9de641fde03368))
* **server:** return capture_ui_snapshot images as ImageContent. Made by https://github.com/dipsy ([3667891](https://github.com/Arenukvern/mcp_flutter/commit/3667891a82bebc480b627f7f7641ee2bee40b219))
* **tool:** detect repo root from a linked worktree in build_skill_assets ([87c5cc8](https://github.com/Arenukvern/mcp_flutter/commit/87c5cc880bbe2272f7f1dbcdd5a284a1962c4c72))
* **tool:** detect repo root from a linked worktree in build_skill_assets ([3ea5433](https://github.com/Arenukvern/mcp_flutter/commit/3ea54336d2132b6fa09a1096e75a425c6503960b))


### Documentation

* Add Ask DeepWiki badge to README ([6975f88](https://github.com/Arenukvern/mcp_flutter/commit/6975f88acf033d14c17213c532af2fd441c8f2b0))
* add chrstphe as a contributor for doc, and platform ([9b6fd6b](https://github.com/Arenukvern/mcp_flutter/commit/9b6fd6b17e6ec869b4197d07792086b710fa7b15))
* add dipsy as a contributor for code, maintenance, and bug ([99d669e](https://github.com/Arenukvern/mcp_flutter/commit/99d669e8b580a698bee8fca0ac87d4eb1beba460))
* add wenyue as a contributor for code, and maintenance ([41fc0e6](https://github.com/Arenukvern/mcp_flutter/commit/41fc0e6d68eb95e5c71b1486a336721486e2f00f))
* update .all-contributorsrc ([35101e0](https://github.com/Arenukvern/mcp_flutter/commit/35101e0fd70e7e0902a61723ff0502bdff9c1078))
* update .all-contributorsrc ([1ccbbce](https://github.com/Arenukvern/mcp_flutter/commit/1ccbbcecb7dd26e92f559cd49da8eceefd88cc95))
* update .all-contributorsrc ([57e2178](https://github.com/Arenukvern/mcp_flutter/commit/57e2178666998d5db6d5758e860b026efc094816))
* update README.md ([3d4399f](https://github.com/Arenukvern/mcp_flutter/commit/3d4399f0b8c83f773267ecfacd0cafadc1cfd219))
* update README.md ([c055f5a](https://github.com/Arenukvern/mcp_flutter/commit/c055f5afcd198a851c6b3d7a43901d2d289416c7))
* update README.md ([a15e2bc](https://github.com/Arenukvern/mcp_flutter/commit/a15e2bc87cbb5a01196ef1162db4e6291c47593c))

## [4.0.0-dev.7](https://github.com/Arenukvern/mcp_flutter/compare/v4.0.0-dev.6...v4.0.0-dev.7) (2026-07-18)


### Features

* **mcp_toolkit:** expose isSelected flag in semantic snapshot nodes ([64a35af](https://github.com/Arenukvern/mcp_flutter/commit/64a35afaec15b4e58d95bbbaa43a6be1d62fc092))


### Bug Fixes

* **mcp_toolkit:** don't double-dispatch tap on desktop when semantic action succeeds ([ab6fc27](https://github.com/Arenukvern/mcp_flutter/commit/ab6fc27239a5c92d527d1ce7582c00d0454c2572))
* **mcp_toolkit:** tap double-dispatch on desktop + expose isSelected in semantic snapshot ([af2da1a](https://github.com/Arenukvern/mcp_flutter/commit/af2da1a744953ad7188548ac9cf445a485f83d26))


### Documentation

* add dipsy as a contributor for code, and maintenance ([fea5eab](https://github.com/Arenukvern/mcp_flutter/commit/fea5eabe561479516f3e240220b8fdff5abbdf98))
* update .all-contributorsrc ([1f670f2](https://github.com/Arenukvern/mcp_flutter/commit/1f670f2d17ca1e554d3774f707525ca2dee498d6))
* update README.md ([d078171](https://github.com/Arenukvern/mcp_flutter/commit/d078171e8c50aebeb3d1572474ce1a83b0e19400))
* update star history chart to README ([46e5d89](https://github.com/Arenukvern/mcp_flutter/commit/46e5d8998055c75466d2b3b167abbc7e0fac5516))

## [4.0.0-dev.6](https://github.com/Arenukvern/mcp_flutter/compare/v4.0.0-dev.5...v4.0.0-dev.6) (2026-07-05)


### Bug Fixes

* add FMT_MODE_PRELUDE to boundary-audit skill and sync assets ([81f788c](https://github.com/Arenukvern/mcp_flutter/commit/81f788cbaafde6ff70105e106eed0b55edfa2061))
* add missing closing parenthesis in dynamic tools registration ([72f4c90](https://github.com/Arenukvern/mcp_flutter/commit/72f4c9075322a35b9388251d2182ac31bac85724))


### Documentation

* architecture cleanup, intentcall, flutter mcp toolkit purpose ([b1609bf](https://github.com/Arenukvern/mcp_flutter/commit/b1609bff17ad95d5b1b2a04271640b44d935c2d8))

## [4.0.0-dev.5](https://github.com/Arenukvern/mcp_flutter/compare/v4.0.0-dev.4...v4.0.0-dev.5) (2026-06-21)


### Bug Fixes

* align release checks with Flutter SDK pins ([175ca58](https://github.com/Arenukvern/mcp_flutter/commit/175ca5875591eca6238f2326bd3a450338827f99))

## [4.0.0-dev.4](https://github.com/Arenukvern/mcp_flutter/compare/v4.0.0-dev.3...v4.0.0-dev.4) (2026-06-18)


### Bug Fixes

* **release:** sync package changelogs for pub publish ([6dfca08](https://github.com/Arenukvern/mcp_flutter/commit/6dfca082e1b1472d2913887c93fb54b908eb9e6b))

## [4.0.0-dev.3](https://github.com/Arenukvern/mcp_flutter/compare/v4.0.0-dev.2...v4.0.0-dev.3) (2026-06-17)


### Bug Fixes

* **release:** exercise release token for 4.0.0-dev.3 ([142e2b4](https://github.com/Arenukvern/mcp_flutter/commit/142e2b4bb2677b19d0c8859e11907a3fac1bcc44))

## [4.0.0-dev.2](https://github.com/Arenukvern/mcp_flutter/compare/v4.0.0-dev.1...v4.0.0-dev.2) (2026-06-17)


### Features

* add steward hosted dependency gate ([3b91408](https://github.com/Arenukvern/mcp_flutter/commit/3b91408f266480d7822df409c2efbfc34f45e99f))
* promote hosted dependency steward gate ([82868e8](https://github.com/Arenukvern/mcp_flutter/commit/82868e83145fd9c56dbd45f677c42ea39b60e4ce))


### Bug Fixes

* https://github.com/drown0315 broken link ([48fe450](https://github.com/Arenukvern/mcp_flutter/commit/48fe4509f5b1ab47e2f7ae588c467ea01b57f85d))
* json ([c67e8fe](https://github.com/Arenukvern/mcp_flutter/commit/c67e8fe5773c9a5da94e018c1dbc507556e6cce1))
* **mcp_toolkit:** VM isolateId causes tool validation error ([37fcaa8](https://github.com/Arenukvern/mcp_flutter/commit/37fcaa8442f6ffed6d236ff6e40a0fec1381c6cc))
* use deterministic dogfood tracker merge ([3e07d3a](https://github.com/Arenukvern/mcp_flutter/commit/3e07d3a5baffdb2afdd14f052d718d2cace0ab70))


### Documentation

* persist steward proof summaries ([339b20f](https://github.com/Arenukvern/mcp_flutter/commit/339b20f9ad6b9aea6856016aa1ce137b7150e89b))
* prepare runtime text input steward proof ([87c493c](https://github.com/Arenukvern/mcp_flutter/commit/87c493c8fb880c58572aa7b59d74e368a68b5144))
* record bounded steward h5 adoption ([bf21f6f](https://github.com/Arenukvern/mcp_flutter/commit/bf21f6f1b0648f0fdcb0d97c84ab3174a0c23701))
* record steward adoption evidence ([fd0c059](https://github.com/Arenukvern/mcp_flutter/commit/fd0c0597d0a7c57e3643a0cc423926ca4fbc5f96))
* refresh direct steward proof summaries ([638b970](https://github.com/Arenukvern/mcp_flutter/commit/638b970b538484f36ba27f77a08bb396b8e08255))
* refresh steward h5 proof summary ([d74a524](https://github.com/Arenukvern/mcp_flutter/commit/d74a5247b4602f2a49bd0e33dcb4fd593f1825d0))
* update GitNexus project details and enhance harness engineering lifecycle documentation ([9245d8f](https://github.com/Arenukvern/mcp_flutter/commit/9245d8fa2d7d1789b7d5cf4cf3392834877e8774))

## [3.1.1](https://github.com/Arenukvern/mcp_flutter/compare/v3.1.0...v3.1.1) (2026-06-05)


### Bug Fixes

* **codegen-init:** add correct pubspec dependency ([dbbb32d](https://github.com/Arenukvern/mcp_flutter/commit/dbbb32d904dd9e8613b6c5236b3e5bf645f2724c))
* **codegen-init:** add correct pubspec dependency ([0fb5230](https://github.com/Arenukvern/mcp_flutter/commit/0fb52307df316d06a8074c46e51027ea7ad9cda9))
* **codegen-init:** use published mcp_toolkit package name ([9d46ba3](https://github.com/Arenukvern/mcp_flutter/commit/9d46ba3c4221f3d6157d6b5568faac51365645d6))
* **codegen-init:** use published mcp_toolkit package name ([#1](https://github.com/Arenukvern/mcp_flutter/issues/1)) ([a53a908](https://github.com/Arenukvern/mcp_flutter/commit/a53a908320ff1ba3e0b117f29ba3f0c7f0bf5bd3))


### Documentation

* add drown0315 as a contributor for code, maintenance, and bug ([192cba5](https://github.com/Arenukvern/mcp_flutter/commit/192cba5917dd9143e74b7f4f9da7a9fce7f22acf))
* add druyang as a contributor for code, maintenance, and bug ([3da354e](https://github.com/Arenukvern/mcp_flutter/commit/3da354e40b24879efc78a1a3e6803845e5da0909))
* update .all-contributorsrc ([a24a9ff](https://github.com/Arenukvern/mcp_flutter/commit/a24a9ff0efec6eb9c5a27098913a1245db860a40))
* update .all-contributorsrc ([33c1495](https://github.com/Arenukvern/mcp_flutter/commit/33c1495584bf69603ea4521bb6ad3c32d6dd1157))
* update README.md ([54bbf4d](https://github.com/Arenukvern/mcp_flutter/commit/54bbf4d6aaaf904fa6316987c2010550dc1f776d))
* update README.md ([52fd2d5](https://github.com/Arenukvern/mcp_flutter/commit/52fd2d5a79e56740a8556655969c62fb89f813eb))

## [Unreleased]

### Added

- `fmtk` short CLI alias for `flutter-mcp-toolkit`, including release artifacts and install script smoke checks.
- Gating CI: `make check-intentcall-hosted-consumer` for hosted consumer proof, plus `make check-intentcall-sibling-matrix` / `.github/workflows/intentcall_eval.yml` for sibling upstream matrix regression proof.
- `make macos-validate-runtime` helper (`tool/evals/run_macos_validate_runtime.sh`) for I5 macOS dogfood.
- intentcall: `xsoulspace_lints` (`library.yaml` / `app.yaml`); `make analyze`; pre-release warnings on all packages ([intentcall/PRE_RELEASE.md](intentcall/PRE_RELEASE.md)); IntentCall consumer guide.
- Phase 7 **7.1–7.3, 7.6**: `intentcall/` workspace; pub.dev metadata; hosted consumer docs; moved publish dry-run ownership to the IntentCall repository.
- Phase 7 **7.1/7.2**: all `intentcall_*` packages started under `intentcall/packages/`; hosted consumer cutover now uses pub.dev packages.
- `flutter_test_app` web dogfood: `WebMcpPublishAdapter` via `agent_web_mcp_dogfood.dart`; Xcode intentcall Codegen Run Script (ios/macos).
- `flutter-mcp-toolkit init intentcall-platform` — idempotent Gradle, manifest, `index.html`, and codegen shell hooks with `--check` for CI.
- `fmt_migrate_agent_entries` MCP tool (report-only default; `apply: true` to rewrite sources).
- `intentcall_platform` thin Flutter plugin + `intentcallInvokeLinkListener` (`app_links`) for `intentcall://invoke/<qualifiedName>`.
- CI / `make check-contracts`: `codegen sync --check` on `flutter_test_app`.
- ADR [0008](decisions/0008_web_agent_invoke_js_only.mdx): web `/agent/invoke` Flutter route optional (JS + WebMCP sufficient).

### Changed

- Raised workspace Dart SDK floor to `>=3.12.0 <4.0.0` across packages and updated fixture expectations.
- Added Flutter SDK floor `>=3.44.0 <4.0.0` for Flutter packages (`mcp_toolkit`, `flutter_test_app`) and bumped server Docker toolchain images/checks to `dart:3.12.0-sdk`.
- **Breaking:** `mcp_server_dart/lib/flutter_mcp_core.dart` no longer promises compatibility for removed private session/state/snapshot internals. Downstream code should import `intentcall_session` for `IntentSessionManager`, `StateStore`, `StateLockManager`, `SafeFileWriter`, and `IntentSnapshotStore`; Flutter MCP keeps only its server-local `FlutterSessionConnector` adapter.
- `ToolRegistration` / `ResourceRegistration` canonical types moved to `intentcall_core`; kernel re-exports (extract-friendly).
- Dogfood harness paths use `--dart-define=INTENTCALL_HARNESS_ROOT` / `INTENTCALL_VISUAL_RECONSTRUCT_ROOT`.
- `MigrateAgentEntriesMigrator` moved to `intentcall_core` (shared by CLI and MCP tool).
- `intentcall_testing`: ecsly-style builder → `invokeWire` → `AgentResult.envelope` test.

## [3.1.0] - 2026-05-25

### Added

- Platform-view-aware visual capture: widget-tree `captureHints` detect `AndroidView` / `UiKitView` / `AppKitView` / `HtmlElementView` / `PlatformViewLink` (and weak `Texture` hints).
- macOS showcase `AppKitView` panel (`showcase.platform.stub` native factory) and **web** `HtmlElementView` via conditional imports (`platform_view_showcase_{stub,macos,web}.dart`, `registerShowcasePlatformView()` in `main()`).
- `ConnectionContext.debugViewDetailsPayload` / `debugViewScreenshotsPayload` test seams; `CoreConnectionTarget.browserDebugPort` for sticky Chrome CDP discovery.
- `get_screenshots` / `capture_ui_snapshot` with `mode: auto` upgrade to `desktop_window` when platform views are detected and host truth capture is viable (macOS, iOS Simulator, or web CDP/SCK).
- `flutter_layer` captures attach `warnings` and `captureHints` when platform views are present.
- macOS host `desktop_window` capture for **iOS Simulator** targets (Simulator window + VM PID).
- Web tab capture ([ADR 0007](decisions/0007_web_headful_tab_capture.mdx)): `WebBrowserScreenshotService` — **macOS SCK → Chrome CDP → `flutter_layer`**; `Page.captureScreenshot`; discovery via sticky port, `--web-browser-debugging-port`, process scan, `/json/list`; metadata `captureBackend: cdp` | `macos_host`.
- CLI global flags `--web-browser-debugging-port`, `--web-port`; hermetic tests `web_cdp_*_test.dart`; opt-in `RUN_WEB_CDP_INTEGRATION=1`.
- Swift visual-capture helper `focus` command; `focus_window` MCP tool (`fmt_focus_window`).
- `validate-runtime` skips `flutter_layer` fallback when platform views are detected; executor recovery handles focus+capture retry (`capturePlatformViewsDetected`, `captureFocusAttempted`, `desktopCaptureRetried`).
- Shared [`desktop_capture_recovery`](mcp_server_dart/lib/src/capabilities/visual_capture/desktop_capture_recovery.dart) dedupes host capture retry (no duplicate `focus_window` steps in validate-runtime).
- Weak `Texture` tier: `captureHints.weakSignalsDetected` + `recommendedMode: desktop_window` advisory without `auto` upgrade; distinct `flutter_layer` warning.
- `MCPToolkitBinding.captureHintsContributor` for WGPU/custom-engine apps without platform-view widgets (`mcp_toolkit` depends on `flutter_mcp_toolkit_core` via path).
- `get_screenshots` image-only MCP responses include routing metadata in `meta` and a leading JSON `TextContent` block.
- `scripts/stop_showcase.sh` and `make showcase-stop`; showcase logs/PID under `.showcase/`; `run_showcase.sh` stops previous instances on start and exit.

### Fixed

- `get_view_details` `captureHints` use a full element-tree scan (widget-tree JSON remains depth-capped); showcase platform views detected reliably on macOS and web.
- Executor `_hintsFromPayload` trusts app-embedded `captureHints` instead of re-parsing a truncated widget tree.
- Live integration tests decode MCP `CoreError`-only tool failures and assert `auto` → `desktop_window` routing when host capture is unavailable.
- Executor preserves weak `captureHints` on `flutter_layer` success (not only `platformViewsDetected`).
- Web showcase no longer throws `unregistered_view_type` for `showcase.platform.stub` (`defaultTargetPlatform` on Mac host no longer selects `AppKitView` on web builds).

### Documentation

- ADR [0006](decisions/0006_platform_view_capture_routing.mdx), [0007](decisions/0007_web_headful_tab_capture.mdx) (Phase A + B shipped); decision indexes updated.
- `mcp_server_dart/README.md`, debug/runtime-validation skills, `flutter_test_app/README.md`, `run_showcase.sh` comments aligned with web CDP and dual-platform showcase.

## [3.0.7] - 2026-05-20

### Fixed

- `doctor` now honors global `--vm-service-uri` when subcommand `--target` is omitted (same resolution as `validate-runtime`).
- `vm_not_connected` responses include `stickyEndpoint`, discovery diagnostics, and `suggestedActions` for faster recovery after hot restart.
- Re-attach after a dropped VM session surfaces `meta.recovery` (`reattachedTo`, `previousEndpoint`, `decision`).

### Added

- `semantic_snapshot` returns `interactionSurface` (`flutter_widgets`, `hybrid`, `game_canvas`, `empty`) so agents know when tap-by-ref will not work.
- `evaluate_dart_expression` accepts optional `libraryUri` and returns `details.errorKind` (`compilation`, `library_not_found`, `transport`).
- `wait_for` predicate kind `noError` — waits until the app error monitor is empty.

### Documentation

- `flutter-mcp-toolkit-setup` and `flutter-mcp-toolkit-inspect` skills: doctor triage, `batch` inspect recipe, `flutter_layer` screenshots, `interactionSurface` guidance (regenerated `skill_assets.g.dart`).

## [3.0.6] - 2026-05-20

### Fixed

- Root `install.sh` supports `curl ... | bash` and installs outside a git clone: safe `BASH_SOURCE` under `set -u`, optional default version from repo `VERSION` / `runtime_version.dart`, GitHub `releases/latest` fallback, and clear usage when version cannot be resolved.

### Changed

- Release binaries: drop `darwin-x64` (Intel Mac). macOS releases are Apple Silicon (`darwin-arm64`) only; `linux-x64` unchanged.

## [3.0.5](https://github.com/Arenukvern/mcp_flutter/compare/v3.0.4...v3.0.5) (2026-05-19)

### Bug Fixes

- readme ([b95e8b3](https://github.com/Arenukvern/mcp_flutter/commit/b95e8b3d25c5529e21c79a3b06ebd97524573671))

## [3.0.4] - 2026-05-19

### Fixed

- docs.page site configuration: logo, favicon, social preview image, Flutter brand theme (`#02569B`), header and anchor links, SEO defaults, and content settings in `docs.json` with assets under `docs/assets/`.

## [3.0.3] - 2026-05-19

### Fixed

- `flutter-mcp-toolkit init` skill writers failed when bundled skill `flutter-mcp-toolkit-repo-maintainer` lacked the required `<!-- @FMT_MODE_PRELUDE -->` marker; marker restored and `skill_assets.g.dart` regenerated.
- CLI daemon integration test forces `get_vm` to fail via an explicit invalid VM target so structured-error assertions stay deterministic when a local Flutter debug app is auto-discovered.

## [3.0.2] - 2026-05-19

### Added

- Marketplace distribution docs: [marketplace_copy.yaml](docs/ai_agents/marketplace_copy.yaml) (listing SSOT), [marketplace_distribution.mdx](docs/ai_agents/marketplace_distribution.mdx), and [marketplace_submission_runbook.mdx](docs/contributing/marketplace_submission_runbook.mdx) (Claude, Cursor, Codex, skills.sh, Smithery, MseeP).
- Plugin store assets under [plugin/assets/](plugin/assets/): `original_logo.png`, `icon.png` (256), `logo.png` (512), `screenshot-1.png`, `screenshot-2.png`, plus capture/regeneration notes in [plugin/assets/README.md](plugin/assets/README.md).
- Codex `interface` metadata in [plugin/.codex-plugin/plugin.json](plugin/.codex-plugin/plugin.json) (display copy, legal URLs, asset paths).
- CI: `check_changelog_markdown.sh` wired into `make check-contracts` (Keep a Changelog / MD052).

### Changed

- Plugin and marketplace descriptions now emphasize the **dynamic registry** (custom MCP tools/resources at runtime via `mcp_toolkit`), not only static inspect/control MCP tools.
- Claude plugin and marketplace versions included in release-please and `check_version_sync.sh` (with Cursor/Codex).
- Codex plugin `homepage` / `repository` point at `Arenukvern/mcp_flutter` (was separate `flutter-mcp-toolkit` repo URL).
- README: **Install from marketplaces** section; [plugin/README.md](plugin/README.md) documents static + dynamic architecture and all eight bundled skills.
- `check_plugin_surfaces.sh` fails if marketplace/plugin descriptions omit dynamic/custom positioning.
- MCP server instructions reference skill `flutter-mcp-toolkit-custom-tools` for dynamic tool flows.
- Maintainer skill `flutter-mcp-toolkit-repo-maintainer` documents marketplace copy, distribution, and submission runbook.

### Documentation

- [docs/ai_agents/overview.mdx](docs/ai_agents/overview.mdx): three-layer model (host MCP, in-app toolkit, dynamic registry); Cursor/Codex git marketplace install.
- [docs/start_here/docs_map.mdx](docs/start_here/docs_map.mdx) and [contribution_guide.mdx](docs/contributing/contribution_guide.mdx) link marketplace docs.

## [3.0.1] - 2026-05-19

### Added

- Open Agent Skills ecosystem: repo-root [`skills/`](skills/) symlink to [`plugin/skills/`](plugin/skills/), [`.skills.json.example`](.skills.json.example), and install docs in [docs/ai_agents/overview.mdx](docs/ai_agents/overview.mdx) (`npx skills add Arenukvern/mcp_flutter`, [skills.sh](https://skills.sh), team lockfile / CI restore).
- Claude marketplace plugin discovery: `skills` entry in [.claude-plugin/marketplace.json](.claude-plugin/marketplace.json).
- Maintainer skill `flutter-mcp-toolkit-repo-maintainer` for releases, CHANGELOG, and docs (bundled + `.cursor/skills/`).

### Documentation

- Install method matrix and per-agent paths in overview; pointers in README, QUICK_START, llm_install, plugin README, mcp_server_dart README, docs_map, cli_vs_mcp, cli_quick_recipes, contribution_guide, execution_playbook, and `flutter-mcp-toolkit-setup` skill (regenerated via `make sync-skills`).

### Changed

- Release automation: [release-please](https://github.com/googleapis/release-please) on `main` (Release PR → tag → changelog GitHub release); [`.github/workflows/release.yml`](.github/workflows/release.yml) attaches binaries only. Version sync gate: `tool/contracts/check_version_sync.sh`.

## [3.0.0]

Major release. Three pillars:

1. **Capability kernel** — the server's tool surface is now composed from
   `Capability` instances registered into an `McpHost`. The kernel applies
   the capability prefix and bridges into `dart_mcp`'s `ToolsSupport`.
2. **Playwright-style interaction layer** — prefixed tools that let an
   AI agent drive a running Flutter app the way a user does, with semantic
   refs and a snapshot/staleness contract.
3. **Plugin-first install** — a Claude Code marketplace plugin bundles
   skills, agent, and MCP server into one `install.sh` step; CLI gains
   `init <agent>` for Cursor / Codex / etc.

The locked v3.0.0 surface is checked in at
[`tool/contracts/expected_tool_surface.txt`](tool/contracts/expected_tool_surface.txt)
and pinned by
[`mcp_server_dart/test/tool_surface_snapshot_test.dart`](mcp_server_dart/test/tool_surface_snapshot_test.dart).

### Plugin layout

- Renamed bundled Cursor/Codex skill **`custom-toolkit-tools`** → **`flutter-mcp-toolkit-custom-tools`** (directory `plugin/skills/…`, frontmatter `name`, and `SkillAssets` id). Update any prompts or automation that referenced the old skill id; run `make sync-skills` after pulling.
- Renamed Claude subagent file `plugin/agents/flutter-inspector.md` → `plugin/agents/flutter-mcp-toolkit-runtime.md` with `name: flutter-mcp-toolkit-runtime` so the agent aligns with `flutter-mcp-toolkit-*` surfaces and no longer shares a slug with the legacy MCP `mcpServers` key **`flutter-inspector`**.
- **Consolidated:** Claude Code marketplace, Cursor/Codex manifests, MCP config, installer, version pin, `flutter-mcp` + `flutter-mcp-cli-runtime-validation` skills, and the `flutter-mcp-toolkit-runtime` agent now live under **`plugin/`** only. [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) `source` is **`./plugin`**. Removed the duplicate **`flutter_mcp_plugin/`** tree.
- `plugin/` (Claude / Cursor / Codex marketplace): canonical **`plugin/mcp.json`** uses MCP key **`flutter-mcp-toolkit`**; `tool/contracts/check_plugin_surfaces.sh` accepts **`flutter-mcp-toolkit`** or legacy **`flutter-inspector`** and requires **`flutter-mcp-toolkit-server`** in `command`.

### Docs

- Install/migration docs (`llm_install.md`, `mcp_server_dart/README.md`, `docs/start_here/migration_v2_to_v3.mdx`), plugin spec §5–§6.1, and `plugin/skills/flutter-mcp/SKILL.md`: clarify **`flutter-inspector`** as legacy **`mcpServers`** id vs Claude subagent **`flutter-mcp-toolkit-runtime`**; regenerated `skill_assets.g.dart`.
- Plugin skills (`plugin/skills/…`): `validate-runtime` now documents `--vm-service-uri`, automatic `flutter_layer` retry after failed `desktop_window` capture, and `captureFallbackUsed`; port-conflict example uses current `flutter run` flags; covers binaries, `mcpServers` keys, `validate-runtime`, and links to canonical configs.
- [mcp_server_dart/README.md](mcp_server_dart/README.md): Cline / Cursor / Claude examples use **`flutter-mcp-toolkit`** + updated Cursor deeplink; removed stale `--no-resources` / `flutter_inspector_mcp` guidance.
- `mcp_toolkit` package README: golden-path note for `validate-runtime` targeting / fallback.

### BREAKING

#### MCP tool names are now prefixed by capability id

All MCP tools surface under the `fmt_` capability prefix (Flutter MCP
Toolkit). Calls to legacy unprefixed names return `tool_not_found`. The
CLI catalog vocabulary stays bare for intrinsic tools — `flutter-mcp-toolkit exec --name tap_widget`
still works; MCP publishes `fmt_tap_widget`. Dynamic-registry commands use
their full `fmt_*` spelling in both CLI and MCP. See
[docs/start_here/migration_v2_to_v3.mdx](docs/start_here/migration_v2_to_v3.mdx)
for the smallest-possible-diff guide.

| v2 (legacy)                             | v3 (MCP `tools/call` name)            |
| --------------------------------------- | ------------------------------------- |
| `tap_widget`                            | `fmt_tap_widget`                      |
| `enter_text`                            | `fmt_enter_text`                      |
| `reveal_search`                         | `fmt_reveal_search`                   |
| `scroll`                                | `fmt_scroll`                          |
| `long_press`                            | `fmt_long_press`                      |
| `swipe`                                 | `fmt_swipe`                           |
| `drag`                                  | `fmt_drag`                            |
| `hover`                                 | `fmt_hover`                           |
| `press_key`                             | `fmt_press_key`                       |
| `semantic_snapshot`                     | `fmt_semantic_snapshot`               |
| `wait_for`                              | `fmt_wait_for`                        |
| `fill_form`                             | `fmt_fill_form`                       |
| `navigate`                              | `fmt_navigate`                        |
| `handle_dialog`                         | `fmt_handle_dialog`                   |
| `connect_debug_app`                     | `fmt_connect_debug_app`               |
| `discover_debug_apps`                   | `fmt_discover_debug_apps`             |
| `get_vm`                                | `fmt_get_vm`                          |
| `get_extension_rpcs`                    | `fmt_get_extension_rpcs`              |
| `hot_reload_flutter`                    | `fmt_hot_reload_flutter`              |
| `hot_restart_flutter`                   | `fmt_hot_restart_flutter`             |
| `hot_reload_and_capture`                | `fmt_hot_reload_and_capture`          |
| `evaluate_dart_expression`              | `fmt_evaluate_dart_expression`        |
| `get_recent_logs`                       | `fmt_get_recent_logs`                 |
| `get_view_details`                      | `fmt_get_view_details`                |
| `get_app_errors`                        | `fmt_get_app_errors`                  |
| `get_screenshots`                       | `fmt_get_screenshots`                 |
| `capture_ui_snapshot`                   | `fmt_capture_ui_snapshot`             |
| `inspect_widget_at_point`               | `fmt_inspect_widget_at_point`         |
| `debug_dump_layer_tree` (`--dumps`)     | `fmt_debug_dump_layer_tree`           |
| `debug_dump_semantics_tree` (`--dumps`) | `fmt_debug_dump_semantics_tree`       |
| `debug_dump_render_tree` (`--dumps`)    | `fmt_debug_dump_render_tree`          |
| `debug_dump_focus_tree` (`--dumps`)     | `fmt_debug_dump_focus_tree`           |
| `listClientToolsAndResources`           | `fmt_list_client_tools_and_resources` |
| `runClientTool`                         | `fmt_client_tool`                     |
| `runClientResource`                     | `fmt_client_resource`                 |

The dynamic-registry host trio
(`fmt_list_client_tools_and_resources`, `fmt_client_tool`, `fmt_client_resource`)
uses the same `fmt_*` names on MCP and in `exec --name`. Resource URIs
(`visual://localhost/...`) are unchanged.

#### Server and CLI binaries renamed

- `flutter_inspector_mcp` → **`flutter-mcp-toolkit-server`** (the MCP server).
- `flutter_mcp_cli` → **`flutter-mcp-toolkit`** (the CLI).
- The MCP `serverInfo.name` advertised on initialize is now
  `flutter-mcp-toolkit-server`.

Update any `mcpServers` config entry, shell alias, Docker invocation, or
CI script that referenced the old names. The new root `install.sh`
updates `PATH` for you on first run.

#### Strict wire surface

- All MCP tool/resource errors emit a single envelope:
  `code`, `message`, `details`, `descriptor`, `recovery`. Code paths that
  parsed top-level `category` / `retryable` / `exitCode` must read
  `error.descriptor` instead.
- Typed parsing hard cut: no string-encoded object/list/bool coercions.
- Tool argument schemas default to `additionalProperties: false` unless
  explicitly opened.
- `connection.targetId` now requires full VM websocket URIs
  (`ws://.../ws`). Legacy `host:port` ids are rejected with migration
  guidance to URI ids or `connection.uri`.
- Top-level `host` / `port` / `uri` aliases on tool arguments are
  rejected; pass them inside the nested `connection` object.

### Added

#### Capability kernel

- `packages/server_capability_kernel/` — pure-Dart contracts: `Capability`,
  `CapabilityContext`, `HostService`, `CommandRunner`, prefix validators,
  and a testing library shipping `FakeCommandRunner` /
  `FakeCapabilityContext`.
- `packages/server_capability_core/` — the bundled `fmt` capability. Registers all 27
  Playwright-style tools plus 4 `--dumps` tools when
  `dumps_supported=true`. No Flutter dependency on the server side.
- `packages/core/` — pure-Dart command hierarchy
  (`CoreCommand`, `CoreResult.toErrorEnvelopeJson`) and value types
  shared between server, CLI, and capability core.
- `McpHost` registry on the server applies the `<capabilityId>_` prefix
  with collision enforcement. `DartMcpDispatchBridge` publishes prefixed
  tools into `dart_mcp`'s `ToolsSupport`.

#### Playwright-style interaction layer

- New interaction tools that let an AI agent drive a running Flutter app
  the way a user does:
  - `semantic_snapshot` returns a compact JSON accessibility tree of
    interactive widgets with stable `ref` strings (`s_0`, `s_1`, ...) and
    a monotonically incrementing `snapshot_id`.
  - `tap_widget`, `long_press`, `enter_text`, `scroll`, `swipe`, and
    `drag` target widgets by `ref`. Each tool uses a two-tier dispatch:
    semantic actions first (`SemanticsOwner.performAction`), then
    synthetic pointer events via
    `GestureBinding.instance.handlePointerEvent` when no semantic action
    is available. Responses include a `via` field
    (`semantic_action` | `pointer_events` | `editable_state` |
    `pointer_scroll_event`).
  - All interaction tools accept an optional `snapshotId`; if it doesn't
    match the current snapshot the call returns a `stale_snapshot`
    envelope with `providedSnapshotId` and `currentSnapshotId`.
  - `scroll` direction follows the Playwright convention
    (direction = which content to reveal).
  - `enter_text` falls back to
    `EditableTextState.userUpdateTextEditingValue` so
    `TextInputFormatter`s and `onChanged` fire correctly.
- `hot_reload_and_capture` fuses hot reload, screenshot, semantic
  snapshot, and app errors into a single response for the agent
  edit/preview loop.
- `evaluate_dart_expression` runs a Dart expression against the root
  library in the running isolate (e.g. `AgentState.instance.counter`)
  and returns `{result, kind, classRef}`.
- `get_recent_logs` exposes a 200-entry ring buffer of recent
  `print` / `debugPrint` output captured from the running app.

#### `flutter-mcp-toolkit init <agent>`

- New `init` subcommand auto-detects mode and writes per-target skills,
  agent files, and manifests for Claude Code, Cursor, Codex, and other
  supported agents in one call.
- `codegen-init` emits the Flutter `main.dart` snippet that bootstraps
  the toolkit on the app side (`MCPToolkitBinding.initialize() / initializeFlutterToolkit()`).
- Replaces the per-agent manual setup docs that shipped in v2.

#### Claude Code marketplace plugin (`plugin/`)

- Plugin manifests (`.claude-plugin/`, `.cursor-plugin/`, `.codex-plugin/`), `mcp.json`, `install.sh`, `EXPECTED_SERVER_VERSION`,
  and a marketplace entry under `.claude-plugin/marketplace.json`.
- Skills shipped include `flutter-mcp-toolkit-{guide,setup,inspect,control,debug}`, `flutter-mcp-toolkit-custom-tools`, `flutter-mcp`, and `flutter-mcp-cli-runtime-validation`.
- `flutter-mcp-toolkit-runtime` agent.
- Skill bodies are bundled into the server (`skill_assets.g.dart`) so
  the CLI can ship them as part of `init`. `make sync-skills`
  regenerates; CI fails PRs that don't.

#### Showcase redesign

- `flutter_test_app` rebuilt as a single-page showcase (`ShowcaseScreen`)
  where every interaction tool has a named target with a `Semantics`
  identifier (`greeting_input_field`, `feature_toggle_switch`,
  `brightness_slider`, `scroll_demo_list`, `hot_reload_marker`,
  `emit_log_button`, `trigger_error_button`, `last_log_display`, ...).
- Integration-test identifiers
  (`about_demo_heading`, `counter_demo_heading`, `counter_demo_icon`,
  `stateful_counter_increment_button`) are preserved.
- `AgentState` singleton lets agents read and mutate showcase state
  through `evaluate_dart_expression`.
- Section heading semantics are isolated for cleaner snapshots.

#### Install and release

- Root `install.sh` for one-command install/upgrade on `darwin-arm64`,
  `darwin-x64`, `linux-x64`. Updates `PATH`.
- Release artifact builder with tarball + checksum generation:
  `tool/release/build_release_artifacts.sh`.
- Tagged release workflow:
  `.github/workflows/release.yml`.

#### Contract quality gates (`make check-contracts`)

- `tool/contracts/check_sdk_parity.sh` — Docker base image vs `pubspec`.
- `tool/contracts/check_error_code_playbook.sh` — error-code surface
  coverage.
- `tool/contracts/check_docs_drift.sh` — CLI help vs docs.
- `tool/contracts/check_plugin_surfaces.sh` — plugin manifest shape.
- `tool/contracts/check_tool_prefix.sh` — single canonical prefix across
  every shipped doc; CHANGELOG migration table covers the locked tool surface.
- CI: `.github/workflows/contract_gates.yml`.
- macOS integration smoke runner:
  `tool/integration/classify_macos_integration_run.sh`.

#### CLI safety + observability

- `flutter-mcp-toolkit doctor [--json] [--target <path>] [--timeout-ms <n>]`
  for CI preflight before VM-dependent operations.
- Safe-write flags for `snapshot create` and `bundle create`:
  `--check`, `--diff`, `--backup`, `--no-overwrite`. Bundle publishing
  is now staged and atomic; the destructive pre-delete is gone.
- Connection UX:
  - Startup stays non-blocking when multiple targets are present.
  - First VM-dependent call auto-attaches when target resolution is
    unambiguous; ambiguity surfaces as `connection_selection_required`
    with `availableTargets` and retry guidance.
  - Optional strict nested `connection` object across every
    VM-dependent MCP tool and dynamic-registry tool.
  - Resource URI query-based connection targeting (`targetId`, `mode`,
    `host`, `port`, `uri`, `forceReconnect`).
- Flutter web auto-discovery:
  - Machine discovery via `flutter attach --machine` with optional
    project / device context.
  - Merged machine + port-scan discovery using URI-id selection
    payloads.
- Runtime discovery flags for the CLI and MCP server:
  - `--flutter-project-dir`
  - `--flutter-device`
  - `--flutter-discovery-timeout-ms`
- CLI / daemon alignment:
  - `exec --args` and daemon `command/execute` / `watch/start` accept
    the same optional `params.args.connection`.
  - `snapshot create` supports per-step
    `args.commands[i].args.connection`.
  - Preconnect no longer returns synthetic `vm_not_connected` for
    ambiguous multi-target paths; ambiguity surfaces as
    `connection_selection_required`.
  - Explicit requested-session attach stays strict; implicit stale
    active-session attach falls back to auto target resolution.
  - `connect` and `session_start` reject mixed native selector args
    with nested `connection`.

### Changed

- The `--use-capability-kernel` flag is gone; the kernel is the only
  registration path. The legacy unprefixed registration mixin was
  deleted in T9.
- README rewritten around the four-step install
  (`install.sh` → `init <agent>` → run app → call tools).
- ARCHITECTURE.md rewritten around the capability kernel and the
  shared-core packages. New ADRs in `docs/decisions/`:
  - `0001_capability_kernel_and_tool_prefix.mdx`
  - `0002_v3_scope_and_consolidation_deferrals.mdx`
- Docs reorganized under `docs/start_here/`, `docs/decisions/`,
  `docs/ai_agents/`, `docs/superpowers/`, `docs/guides/`.
- Dockerfile pinned to `dart:3.11.0-sdk`.

### Fixed

- `resolveCenter` / `resolveBounds` return logical (not physical)
  coordinates — DPR fix that unblocked tap / long-press on high-DPI
  screens.
- `fill_form` actually stops on first toolkit-side failure.
- `wait_for` timeout payload shape pinned by tests; malformed payloads
  route correctly.
- `popUntil` guard and bad-route logging in the toolkit.
- `semantic_snapshot` surfaces scrollable nodes (widgets that advertise
  `scrollUp/Down/Left/Right`) so agents can pass an explicit `ref` to
  `scroll` for the deterministic semantic-action path.
- `scroll` direction-to-`SemanticsAction` mapping realigned with the
  Playwright "direction = reveal" convention:
  `direction: "down"` now maps to `SemanticsAction.scrollUp` (finger up,
  reveals content below), so the Tier 1 path succeeds on real Flutter
  scrollables at the top of their range.

### Flutter Web interaction support

Interaction tools are Tier 1 first on web and degrade predictably when
Tier 1 isn't available:

- `semantic_snapshot`, `evaluate_dart_expression`, `get_recent_logs`,
  `hot_reload_flutter`, and `hot_reload_and_capture` work unchanged on
  web.
- `tap_widget`, `long_press`, and `scroll` (with ref) work when the
  target node exposes the matching `SemanticsAction`. The action shows
  up in the node's `actions` array in `semantic_snapshot`.
- `enter_text` works via `SemanticsAction.setText` or the
  `EditableTextState.userUpdateTextEditingValue` fallback (both work on
  web).
- `swipe(ref, direction)` on web redirects to the matching scroll
  semantic action when `ref` is a scrollable that exposes it; success
  responses return `via: "semantic_action_fallback"` with a `note`
  field explaining the redirect.
- `scroll` without a ref walks the semantics tree for a matching
  scrollable and uses Tier 1.
- When no Tier 1 path exists (tap / long-press on nodes without the
  matching action, swipe on a non-scrollable or no-ref target, drag,
  scroll without any scrollable in tree), web returns a structured
  `web_gesture_not_supported` envelope with a `hint` pointing the agent
  at the right workaround (snapshot for a different ref, add a
  `Semantics` wrapper, or use `evaluate_dart_expression`).

### Removed

- Per-agent manual setup docs — superseded by
  `flutter-mcp-toolkit init <agent>`.
- Manual install / client-setup docs — superseded by `install.sh` +
  `init`.
- `docs/core/built_in_tools` and `docs/core/error_code_playbook` —
  migrated into the plugin's `debug` and `guide` skills.
- `docs/getting_started/` and `docs/troubleshooting/` — content moved
  under `docs/start_here/`.
- `memory-bank/` legacy AI memory directory.
- `mcp_toolkit/devtools_mcp_extension/`.

### Deferred (post-3.0.0)

- Network introspection — see
  [todo/p3_network_introspection.md](todo/p3_network_introspection.md).
- `select_option` form action.
- P4 consolidation set A / C from the audit.

### Version alignment

- `mcp_server_dart`: `3.0.0`
- `mcp_toolkit`: `3.0.0`

### Migration: v2.x → v3.0.0

- Add `fmt_` to every MCP `tools/call` name. See
  [docs/start_here/migration_v2_to_v3.mdx](docs/start_here/migration_v2_to_v3.mdx).
- Update binary names in your `mcpServers` config and any wrapper
  scripts: `flutter_inspector_mcp` → `flutter-mcp-toolkit-server`,
  `flutter_mcp_cli` → `flutter-mcp-toolkit`.
- Replace error parsing that expected top-level `category` /
  `retryable` / `exitCode` with reads against `error.descriptor`.
- Stop sending string-encoded typed values; pass real JSON types only.
- Switch any `targetId` of the form `host:port` to the full
  `ws://.../ws` URI, or pass `connection.uri`.
- Move top-level `host` / `port` / `uri` arguments into the nested
  `connection` object.
- For write-producing commands, prefer `--check --diff` first in
  automation. If overwrite must be blocked, set `--no-overwrite` and
  handle `write_blocked`.
- Use `flutter-mcp-toolkit doctor --json` in CI preflight before
  VM-dependent operations.

## 2.6.1

- old devtools extension removed

## 2.6.0

BREAKING CHANGES:

- Dart SDK updated to 3.10.0 with all dependencies updated to the latest versions

- now VM service auto-reconnect when Flutter app restarts. Huge thank you to [@jkitching](https://github.com/jkitching) for PR! https://github.com/Arenukvern/mcp_flutter/pull/73
- dockerfile for MCP Server - not tested.
  Huge thank you to [@arslanmit](https://github.com/arslanmit) for PR with Dockerfile! https://github.com/Arenukvern/mcp_flutter/pull/64

## 2.5.0

- new tool: `hot_restart_flutter` to perform VM Service Hot Restart from MCP.
- VM service integration method `hotRestart()` with namespaced service discovery fallback.

  Huge thank you to [CommentakMedia](https://github.com/CommentakMedia) for PR with Hot Restart tool and docs! https://github.com/Arenukvern/mcp_flutter/pull/67

## 2.4.0

- mcp_toolkit: ^0.3.0 with breaking changes, see [mcp_toolkit/CHANGELOG.md](https://github.com/Arenukvern/mcp_flutter/blob/main/mcp_toolkit/CHANGELOG.md)

## 2.3.1

- added new examples for MCPToolkit package dynamic tools usage see [flutter_test_app/lib/main.dart](https://github.com/Arenukvern/mcp_flutter/tree/main/flutter_test_app/lib)
- thanks for [@marwenbk](https://github.com/marwenbk) for asking [issue](https://github.com/Arenukvern/mcp_flutter/issues/56).

## 2.3.0

- perf: added more checks for `MCPCallEntry.resourceUri` for MCPToolkit package (MCPToolkit updated to v0.2.3)

## mcp_server_dart

- feat: Added support for saving captured screenshots as files instead of returning them as base64 data, with automatic cleanup of old screenshots. Use (`--save-images`) flag to enable it.

- fix: Fixed various issues with dynamic registry, made logs level error by default.

- added section for RooCode in QUICK_START.md
- disabled resources support by default for RooCode and Cline setups (for unknown reason it doesn't work)

- Huge thank you to [cosystudio](https://github.com/cosystudio) for raising, researching and [describing issues](https://github.com/Arenukvern/mcp_flutter/issues/53) with RooCode MCP server.

## 2.2.2

- Added `--await-dnd` flag to wait until DND connection is established. By default `--no-await-dnd` will be applied.
  There will be 5 seconds timeout for DND connection and then server will start without DND connection.

  This is workaround for MCP Clients which don't support tools updates.
  Important: some clients doesn't support it. Use with caution. (disable for Windsurf, works with Cursor)

Thank you [@rednikisfun](https://github.com/rednikisfun) for [raising issue for Windsurf](https://github.com/Arenukvern/mcp_flutter/issues/51).

## 2.2.1

- Added badge to install Flutter Inspector to Cursor in README.md
- Restored License file

## 2.2.0

### 🎉 Dart Server + Dynamic Tools Registration

### 🔄 BREAKING CHANGES.

- **Server Migration**: The main server is now **`mcp_server_dart`** (Dart-based), replacing the previous TypeScript server (`mcp_server`)
- **Configuration Changes**: Updated command-line arguments and removed environment variables
- **Package Version**: Updated `mcp_toolkit` to `^0.2.0`

### ✨ New Features

1. 🆕 Dynamic Tools Registration
   Flutter apps can now register custom tools at runtime.
   See [video](https://www.youtube.com/watch?v=Qog3x2VcO98) of how it works and how to use it.

2. MCP Tools for Dynamic Registry (part of Dynamic Tools Registration)

- `fmt_list_client_tools_and_resources` - Discover all dynamically registered tools and resources if they are not listed in the AI Assistant (Cursor, Cline, Copilot, Roo Code etc..)
- `fmt_client_tool` - Execute custom tools registered by Flutter applications
- `fmt_client_resource` - Read custom resources registered by Flutter applications
- `getRegistryStats` - Get statistics about the dynamic registry (debug mode only)

### 📦 Migration Guide

1. **Update AI Assistant Configuration**:

   ```json
   {
     "mcpServers": {
       "flutter-mcp-toolkit": {
         "command": "/path/to/mcp_flutter/mcp_server_dart/build/flutter-mcp-toolkit-server",
         "args": [
           "--dart-vm-host=localhost",
           "--dart-vm-port=8181",
           "--resources",
           "--images",
           "--dynamics"
         ],
         "env": {}
       }
     }
   }
   ```

2. **Update Flutter App Dependencies**:
   ```yaml
   dependencies:
     mcp_toolkit: ^0.2.0
   ```

#### For New Users

Follow the updated [Quick Start Guide](QUICK_START.md) for complete setup instructions.

### 🔧 Technical Changes

1. Command Line Interface

- Instead of environment variables, now you can use command-line flags: `--resources`, `--no-resources`, `--images`, `--dumps`, `--dynamics`
- Improved logging with `--log-level` option

2. MCPToolkit API Updates

- New `addEntries()` method to register tools and resources from Flutter app.
- New `MCPCallEntry.tool()` and `MCPCallEntry.resource()` constructors
- Improved error handling with `MCPCallResult`

### 🐛 Bug Fixes

- Fixed connection stability issues
- Improved error handling for VM service disconnections
- Enhanced port scanning reliability
- Better resource cleanup on app restart

### 🙏 Acknowledgments

Special thanks to the community for feedback and testing, and to the Flutter team for the new Dart MCP Server which made Dart MCP Server possible.

---

## Code Rabbit Poem :)

> In the warren of code, new features appear,
> Dynamic tools hop in—now discovery is clear!
> Registries and managers with event-driven flair,
> Flutter and MCP, a seamless new pair.
> With docs and examples, the future looks bright—
> This bunny approves: the registry's just right!
> 🐇✨

## 2.1.0

This release adds experimental Dart MCP Server.
In future I want to replace Typescript server with Dart one.

The reason is simple: Dart has more tooling for Flutter, and it's easier to develop with it.

The reason why I didn't do it earlier - because I started earlier and at the start there was no Dart MCP Server at all, so only when I already developed first version (with autogenerated tools based on Dart VM methods), I asked question on Flutter Discord server and got reply that there is [MCP server fo Dart tooling in development](https://discord.com/channels/608014603317936148/1159561514072690739/1362482189131841718) which sounds so amazing, so at the moment I thought that I don't need to do it myself and stop the project completely.

Then I figured out, that's it was fun time to develop it, and I would happy to try to complete at least one version.

At the same time I've tried Dart MCP Server and it was not working with Cline at all, so I decided to keep the project alive and try to fine tune it instead, while Dart MCP Server was in development.

Now Dart MCP Server mostly works, and I'm happy to migrate to it. However, in the same time, I found new idea of how MCP Server can be used - and it's not only using Dart VM methods, but just other way of thinking of MCP servers.

The current way to write MCP server tools and resources is to have to write server and all the code is on the server side.

However, I found, that it's not ideal, because if you need to secure what information is sent to the server, or just add new tools / resources for specific project it is not great way to do it.

So after experimenting with some ideas (the most of work is on branch feat/mcp-registry-try3), first:

1. Removed extension and moved all logic for tools and resources to the client. (it's released already as Dart MCPToolkit package)
2. Added ability to register new tools and resources on server from client side. (WIP).

Hopefully, the idea will work and will be useful (but maybe not:))

If you want to try dart server - please check [README](mcp_server_dart/README.md) for more details.

For dynamic registry of client tools and resources, please check [issue](https://github.com/Arenukvern/mcp_flutter/issues/32) - will update it during the work.

Have a nice day!

## 2.0.0

This release removes the forwarding server path and refactors all communication to use Dart VM.

Note that setup is changed - see new [Quick Start](QUICK_START.md) and [Configuration](CONFIGURATION.md) docs.

The major change, is that now you can control what MCP Server will receive from your Flutter app.

This is made, by introducing new package - [mcp_toolkit](https://github.com/Arenukvern/mcp_flutter/tree/main/mcp_toolkit).

This package working on the same principle as WidgetBinding - it collects information from your Flutter app and sends it to Dart VM when MCP Server requests it.

You can override or add only tools you need.

For example, if you want to add Flutter tools, you can use `initializeFlutterToolkit()` method like one below.

```dart
MCPToolkitBinding.instance
  ..initialize()
  ..initializeFlutterToolkit();
```

## Poem

Thanks Code Rabbit for poem:

> A hop, a leap, the server's gone,  
> Now all through Dart VM, requests are drawn.  
> No more forwarding, no more relay,  
> Errors and screenshots come straight our way!  
> Toolkit in the app, so neat and spry,  
> Flutter views and details—oh my!  
> 🐇✨

## 1.0.0

Stable release with forwarding server implementation.
