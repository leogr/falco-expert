.PHONY: init check-md-links check-refs-paths check-index-drift check-docs

GOCACHE ?= /tmp/falco-expert-go-build
DOC_CHECK = GOCACHE=$(GOCACHE) go run ./tools/check-docs/main.go

init: ## Initialize git submodules (refs/ data sources)
	git submodule update --init --recursive

check-md-links: ## Validate repo-authored local markdown links
	$(DOC_CHECK) md-links

check-refs-paths: ## Validate repo-authored links into refs/
	$(DOC_CHECK) refs-paths

check-index-drift: ## Validate key navigation indexes against the filesystem
	$(DOC_CHECK) index-drift

check-docs: ## Run all local documentation validation checks
	$(DOC_CHECK) all
