-include Makefile.local # for optional local options

SHARDS ::= shards # The shards command to use
CRYSTAL ::= crystal # The crystal command to use

DOCS_FLAGS ::=

SRC_SOURCES ::= $(shell find src -name '*.cr' 2>/dev/null)
LIB_SOURCES ::= $(shell find lib -name '*.cr' 2>/dev/null)
SPEC_SOURCES ::= $(shell find spec -name '*.cr' 2>/dev/null)

.PHONY: build
build: ## Build the application binary
build: $(SRC_SOURCES) $(LIB_SOURCES) lib
	$(SHARDS) build

.PHONY: test
test: ## Run test suite
test: shard.lock
	$(CRYSTAL) spec

.PHONY: format
format: ## Apply source code formatting
format: $(APP_SOURCES) $(SPEC_SOURCES)
	$(CRYSTAL) tool format src spec

docs: ## Generate API docs
docs: $(SRC_SOURCES) lib
	$(CRYSTAL) docs -o docs $(DOCS_FLAGS)

lib: shard.lock
	$(SHARDS) install

shard.lock: shard.yml
	$(SHARDS) update

.PHONY: clean
clean: ## Remove application binary
clean:
	rm -f $(BIN)/*

.PHONY: help
help: ## Show this help
	@echo
	@printf '\033[34mtargets:\033[0m\n'
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) |\
		sort |\
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo
	@printf '\033[34moptional variables:\033[0m\n'
	@grep -hE '^[a-zA-Z_-]+ \?=.*?## .*$$' $(MAKEFILE_LIST) |\
		sort |\
		awk 'BEGIN {FS = " \\?=.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo
	@printf '\033[34mrecipes:\033[0m\n'
	@grep -hE '^##.*$$' $(MAKEFILE_LIST) |\
		awk 'BEGIN {FS = "## "}; /^## [a-zA-Z_-]/ {printf "  \033[36m%s\033[0m\n", $$2}; /^##  / {printf "  %s\n", $$2}'
