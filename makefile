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
	bash tool/contracts/check_error_code_playbook.sh && \
	bash tool/contracts/check_docs_drift.sh

.PHONY: release-artifacts
release-artifacts:
	cd $(CURDIR) && bash tool/release/build_release_artifacts.sh
