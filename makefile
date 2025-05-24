install: 
	cd $(CURDIR)/mcp_server && npm install && npm run build 
build:
	cd $(CURDIR)/mcp_server && npm run build
inspect:
	cd $(CURDIR)/mcp_server && npm run inspector 
