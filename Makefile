all: lint
.PHONY: env-check lint clean test spm-build api-surface api-surface-swift api-surface-objc api-surface-verify help

# Configuration for API surface
LIBRARY_NAME := DatadogOpenFeatureProvider

# Define default paths for API output files
SWIFT_OUTPUT_PATH ?= api-surface-swift
OBJC_OUTPUT_PATH ?= api-surface-objc

# Use different paths when running in CI
ifeq ($(ENV),ci)
  SWIFT_OUTPUT_PATH := api-surface-swift-generated
  OBJC_OUTPUT_PATH := api-surface-objc-generated
endif

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
	rm -f $(SWIFT_OUTPUT_PATH) $(OBJC_OUTPUT_PATH)

# API Surface Generation
api-surface: api-surface-swift api-surface-objc
	@$(ECHO_TITLE) "API surface generation complete"

api-surface-swift:
	@$(ECHO_TITLE) "make api-surface-swift"
	@echo "Generating Swift API surface..."
	@cd tools/api-surface && \
	swift run api-surface generate \
		--path ../../ \
		--language swift \
		--library-name $(LIBRARY_NAME) \
		--output-file ../../$(SWIFT_OUTPUT_PATH)

api-surface-objc:
	@$(ECHO_TITLE) "make api-surface-objc"
	@echo "Generating Objective-C API surface..."
	@cd tools/api-surface && \
	swift run api-surface generate \
		--path ../../ \
		--language objc \
		--library-name $(LIBRARY_NAME) \
		--output-file ../../$(OBJC_OUTPUT_PATH)

# API Surface Verification (for CI)
api-surface-verify: api-surface-verify-swift api-surface-verify-objc

api-surface-verify-swift:
	@$(ECHO_TITLE) "make api-surface-verify-swift"
	@cd tools/api-surface && \
	swift run api-surface verify \
		--path ../../ \
		--language swift \
		--library-name $(LIBRARY_NAME) \
		--output-file /tmp/api-surface-swift-generated \
		../../$(SWIFT_OUTPUT_PATH)

api-surface-verify-objc:
	@$(ECHO_TITLE) "make api-surface-verify-objc"
	@cd tools/api-surface && \
	swift run api-surface verify \
		--path ../../ \
		--language objc \
		--library-name $(LIBRARY_NAME) \
		--output-file /tmp/api-surface-objc-generated \
		../../$(OBJC_OUTPUT_PATH)

help:
	@echo "Available targets:"
	@echo "  env-check        - Check environment and tool versions"
	@echo "  lint             - Run SwiftLint on source and test files"
	@echo "  test             - Run Swift tests"
	@echo "  spm-build        - Build with Swift Package Manager"
	@echo "  clean            - Clean build artifacts"
	@echo "  api-surface      - Generate both Swift and Objective-C API surfaces"
	@echo "  api-surface-swift - Generate Swift API surface"
	@echo "  api-surface-objc  - Generate Objective-C API surface"
	@echo "  api-surface-verify - Verify API surfaces match expected files"
	@echo "  help             - Show this help message"
