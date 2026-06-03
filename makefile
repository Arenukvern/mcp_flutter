.PHONY: install
install: 
	cd $(CURDIR)/mcp_server_dart && make setup

.PHONY: build
build:
	cd $(CURDIR)/mcp_server_dart && make compile

.PHONY: inspect
inspect:
	cd $(CURDIR)/mcp_server_dart && make inspect 

.PHONY: check-contracts
check-contracts:
	cd $(CURDIR) && \
	bash tool/contracts/check_sdk_parity.sh && \
	bash tool/contracts/check_docs_drift.sh && \
	bash tool/contracts/check_plugin_surfaces.sh && \
	bash tool/contracts/check_version_sync.sh && \
	bash tool/contracts/check_skill_assets_drift.sh && \
	bash tool/contracts/check_changelog_markdown.sh && \
	bash tool/contracts/check_tool_prefix.sh && \
	bash tool/contracts/check_repo_split_paths.sh && \
	bash tool/contracts/check_intentcall_skills_grep.sh && \
	dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart init intentcall-platform \
	  --project-dir flutter_test_app --check && \
	dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart codegen sync \
	  --platform web,android,ios,macos,linux,windows \
	  --project-dir flutter_test_app --check && \
	steward validate skills/

.PHONY: release-artifacts
release-artifacts:
	cd $(CURDIR) && bash tool/release/build_release_artifacts.sh

# Run the flutter_test_app showcase on macOS and print the canonical VM URI
# once the app is ready. Blocks the terminal so the agent can copy the URI
# into subsequent CLI calls (`--args '{"connection":{"targetId":"<uri>"}}'`).
.PHONY: web-showcase webmcp-chrome-args
web-showcase:
	@bash $(CURDIR)/scripts/run_web_showcase.sh

webmcp-chrome-args:
	dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart webmcp chrome-args

.PHONY: showcase showcase-stop
showcase:
	@bash $(CURDIR)/scripts/run_showcase.sh

showcase-stop:
	@bash $(CURDIR)/scripts/stop_showcase.sh

.PHONY: sync-skills
sync-skills:
	dart run mcp_server_dart/tool/build_skill_assets.dart
	@echo "OK: skill assets regenerated"

.PHONY: check-intentcall-integration macos-validate-runtime publish-intentcall-dry-run
check-intentcall-integration:
	bash $(CURDIR)/tool/contracts/check_intentcall_integration.sh

macos-validate-runtime:
	bash $(CURDIR)/tool/evals/run_macos_validate_runtime.sh

publish-intentcall-dry-run:
	bash $(CURDIR)/tool/intentcall/publish_all.sh

.PHONY: dogfood-eval dogfood-eval-static
dogfood-eval:
	bash $(CURDIR)/tool/evals/run_dogfood_eval.sh --merge --run-intentcall-tests

dogfood-eval-static:
	bash $(CURDIR)/tool/evals/run_dogfood_eval.sh --skip-runtime --merge

.PHONY: check-harness
check-harness:
	@test -d ../flutter_harness || (echo "Clone flutter_harness next to mcp_flutter" && exit 1)
	FLUTTER_MCP_TOOLKIT_ROOT="$(CURDIR)" bash ../flutter_harness/tool/harness/check_hs_fixtures.sh

.PHONY: test-harness
test-harness:
	@test -d ../flutter_harness || (echo "Clone flutter_harness next to mcp_flutter" && exit 1)
	cd ../flutter_harness && dart test
