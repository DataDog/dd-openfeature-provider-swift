all: lint
.PHONY: env-check lint clean test spm-build help

REPO_ROOT := $(PWD)
include tools/utils/common.mk

# Default ENV for setting up the repo
DEFAULT_ENV := dev

env-check:
	@$(ECHO_TITLE) "make env-check"
	./tools/env-check.sh

lint:
	@$(ECHO_TITLE) "make lint"
	./tools/lint/run-linter.sh

test:
	@$(ECHO_TITLE) "make test"
	swift test

spm-build:
	@$(ECHO_TITLE) "make spm-build"
	swift build

clean:
	@$(ECHO_TITLE) "make clean"
	swift package clean
	rm -rf .build

help:
	@echo "Available targets:"
	@echo "  env-check - Check environment and tool versions"
	@echo "  lint      - Run SwiftLint on source and test files"
	@echo "  test      - Run Swift tests"
	@echo "  spm-build - Build with Swift Package Manager"
	@echo "  clean     - Clean build artifacts"
	@echo "  help      - Show this help message"
