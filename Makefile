all: lint
.PHONY: env-check lint clean test spm-build help \
		smoke-test smoke-test-ios smoke-test-ios-all

REPO_ROOT := $(PWD)
include tools/utils/common.mk

# Default ENV for setting up the repo
DEFAULT_ENV := dev

# Test env for running iOS tests in local:
DEFAULT_IOS_OS := 18.5
DEFAULT_IOS_PLATFORM := iOS Simulator
DEFAULT_IOS_DEVICE := iPhone 16 Pro

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

# Run smoke tests
smoke-test:
	@$(call require_param,TEST_DIRECTORY)
	@$(call require_param,OS)
	@$(call require_param,PLATFORM)
	@$(call require_param,DEVICE)
	@$(ECHO_TITLE) "make smoke-test TEST_DIRECTORY='$(TEST_DIRECTORY)' OS='$(OS)' PLATFORM='$(PLATFORM)' DEVICE='$(DEVICE)'"
	./tools/smoke-test.sh --test-directory "$(TEST_DIRECTORY)" --os "$(OS)" --platform "$(PLATFORM)" --device "$(DEVICE)"

# Run smoke tests for specified TEST_DIRECTORY using iOS Simulator
smoke-test-ios:
	@$(call require_param,TEST_DIRECTORY)
	@:$(eval OS ?= $(DEFAULT_IOS_OS))
	@:$(eval PLATFORM ?= $(DEFAULT_IOS_PLATFORM))
	@:$(eval DEVICE ?= $(DEFAULT_IOS_DEVICE))
	@$(MAKE) smoke-test TEST_DIRECTORY="$(TEST_DIRECTORY)" OS="$(OS)" PLATFORM="$(PLATFORM)" DEVICE="$(DEVICE)"

# Run all smoke tests using iOS Simulator
smoke-test-ios-all:
	@$(MAKE) smoke-test-ios TEST_DIRECTORY="SmokeTests/spm"
	@$(MAKE) smoke-test-ios TEST_DIRECTORY="SmokeTests/cocoapods"

help:
	@echo "Available targets:"
	@echo "  env-check        - Check environment and tool versions"
	@echo "  lint             - Run SwiftLint on source and test files"
	@echo "  test             - Run Swift tests"
	@echo "  spm-build        - Build with Swift Package Manager"
	@echo "  clean            - Clean build artifacts"
	@echo "  smoke-test       - Run smoke tests for specified directory and platform"
	@echo "  smoke-test-ios   - Run smoke tests for specified directory using iOS Simulator"
	@echo "  smoke-test-ios-all - Run all smoke tests (SPM + CocoaPods) using iOS Simulator"
	@echo "  help             - Show this help message"
