all: env-check repo-setup templates
.PHONY: env-check lint license-check release-tools-test templates clean test spm-build \
		set-ci-secret help smoke-test smoke-test-ios smoke-test-ios-all release-publish-podspecs \
		release-publish-github bump

REPO_ROOT := $(PWD)
include tools/utils/common.mk

# Default ENV for setting up the repo
DEFAULT_ENV := dev

# Test env for running iOS tests in local:
DEFAULT_IOS_OS := latest
DEFAULT_IOS_PLATFORM := iOS Simulator
DEFAULT_IOS_DEVICE := iPhone 16 Pro

env-check:
	@$(ECHO_TITLE) "make env-check"
	./tools/env-check.sh

repo-setup:
	@:$(eval ENV ?= $(DEFAULT_ENV))
	@$(ECHO_TITLE) "make repo-setup ENV='$(ENV)'"
	./tools/repo-setup/repo-setup.sh --env "$(ENV)"

lint:
	@$(ECHO_TITLE) "make lint"
	./tools/lint/run-linter.sh

license-check:
	@$(ECHO_TITLE) "make license-check"
	./tools/license/check-license.sh

release-tools-test:
	@$(ECHO_TITLE) "make release-tools-test"
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools/release/tests -p 'test_*.py'

templates:
	@$(ECHO_TITLE) "make templates"
	./tools/xcode-templates/install-xcode-templates.sh

test:
	@$(ECHO_TITLE) "make test"
	swift test

spm-build:
	@$(ECHO_TITLE) "make spm-build"
	swift build

clean:
	@$(ECHO_TITLE) "make clean"
	./tools/clean.sh --derived-data --pods --xcconfigs

# Set or update CI secrets
set-ci-secret:
	@$(ECHO_TITLE) "make set-ci-secret"
	@./tools/secrets/set-secret.sh

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

# ┌──────────────┐
# │ SDK release: │
# └──────────────┘

# Publish Cocoapods podspecs to trunk
release-publish-podspecs:
	@$(call require_param,ARTIFACTS_PATH)
	@:$(eval DRY_RUN ?= 1)
	@$(ECHO_TITLE) "make release-publish-podspecs ARTIFACTS_PATH='$(ARTIFACTS_PATH)' DRY_RUN='$(DRY_RUN)'"
	DRY_RUN=$(DRY_RUN) ./tools/release/publish-podspec.sh \
		--artifacts-path "$(ARTIFACTS_PATH)" \
		--podspec-name "DatadogOpenFeatureProvider.podspec"

release-publish-github:
	@$(call require_param,GIT_TAG)
	@:$(eval DRY_RUN ?= 1)
	@$(ECHO_TITLE) "make release-publish-github GIT_TAG='$(GIT_TAG)' DRY_RUN='$(DRY_RUN)'"
	DRY_RUN=$(DRY_RUN) zsh ./tools/release/publish-github.sh --tag "$(GIT_TAG)"

bump:
	@$(call require_param,VERSION)
	python3 ./tools/release/release_version.py prepare --version "$(VERSION)"

help:
	@echo "Available targets:"
	@echo "  env-check        - Check environment and tool versions"
	@echo "  repo-setup       - Set up repository with environment configurations"
	@echo "  lint             - Run SwiftLint on source and test files"
	@echo "  license-check    - Check license headers in source files"
	@echo "  release-tools-test - Test release version preparation and validation"
	@echo "  templates        - Install Xcode file templates"
	@echo "  test             - Run Swift tests"
	@echo "  spm-build        - Build with Swift Package Manager"
	@echo "  clean            - Clean build artifacts, pods, and xcconfigs"
	@echo "  set-ci-secret    - Set or update CI secrets"
	@echo "  smoke-test       - Run smoke tests for specified directory and platform"
	@echo "  smoke-test-ios   - Run smoke tests for specified directory using iOS Simulator"
	@echo "  smoke-test-ios-all - Run all smoke tests (SPM + CocoaPods) using iOS Simulator"
	@echo "  release-publish-podspecs - Publish podspecs to CocoaPods trunk"
	@echo "  release-publish-github - Publish the GitHub Release for a validated tag"
	@echo "  bump             - Update release version files and CHANGELOG (VERSION required)"
	@echo "  help             - Show this help message"
