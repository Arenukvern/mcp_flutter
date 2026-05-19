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
	bash tool/contracts/check_changelog_markdown.sh && \
	bash tool/contracts/check_tool_prefix.sh

.PHONY: release-artifacts
release-artifacts:
	cd $(CURDIR) && bash tool/release/build_release_artifacts.sh

# Run the flutter_test_app showcase on macOS and print the canonical VM URI
# once the app is ready. Blocks the terminal so the agent can copy the URI
# into subsequent CLI calls (`--args '{"connection":{"targetId":"<uri>"}}'`).
.PHONY: showcase
showcase:
	@bash $(CURDIR)/scripts/run_showcase.sh

.PHONY: sync-skills
sync-skills:
	dart run mcp_server_dart/tool/build_skill_assets.dart
	@echo "OK: skill assets regenerated"
