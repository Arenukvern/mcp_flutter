.PHONY: test analyze publish-dry-run
AGENTKIT_PKGS := packages/agentkit_schema packages/agentkit_core packages/agentkit_mcp \
	packages/agentkit_webmcp packages/agentkit_gemma packages/agentkit_apple \
	packages/agentkit_android packages/agentkit_platform packages/agentkit_codegen \
	packages/agentkit_testing

test:
	dart test $(AGENTKIT_PKGS)

analyze:
	dart analyze .

publish-dry-run:
	bash ../tool/agentkit/publish_all.sh
