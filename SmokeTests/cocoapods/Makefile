.PHONY: clean install test

REPO_ROOT := ../../
include ../../tools/utils/common.mk

ifeq ($(PLATFORM), iOS Simulator)
SCHEME1 := App Dynamic iOS
SCHEME2 := App Static iOS
endif

ifeq ($(strip $(CURRENT_GIT_COMMIT)),)
    $(error Cannot set COCOAPODS_GIT_REF because CURRENT_GIT_COMMIT is empty)
endif
COCOAPODS_GIT_REF := commit => '$(CURRENT_GIT_COMMIT)'

clean:
	@$(ECHO_SUBTITLE2) "make clean"
	rm -rf Pods

install:
	@$(ECHO_SUBTITLE2) "make install"
	@$(ECHO_INFO) "Preparing for CURRENT_GIT_REF='${CURRENT_GIT_REF}'"
ifeq ($(COCOAPODS_GIT_REF),)
	@$(ECHO_ERROR) "No COCOAPODS_GIT_REF is defined for CURRENT_GIT_REF='$(CURRENT_GIT_REF)'"
	@exit 1
endif
	@$(ECHO_INFO) "Using COCOAPODS_GIT_REF='$(COCOAPODS_GIT_REF)'"
	sed "s|GIT_REFERENCE|${COCOAPODS_GIT_REF}|g" Podfile.src > Podfile
	bundle exec pod update

test:
	@$(call require_param,OS)
	@$(call require_param,PLATFORM)
	@$(call require_param,DEVICE)
	@$(ECHO_SUBTITLE2) "make test OS='$(OS)' PLATFORM='$(PLATFORM)' DEVICE='$(DEVICE)'"
ifeq ($(SCHEME1),)
	@$(ECHO_ERROR) "No SCHEME1 is defined for PLATFORM='$(PLATFORM)'"
	@exit 1
endif
ifeq ($(SCHEME2),)
	@$(ECHO_ERROR) "No SCHEME2 is defined for PLATFORM='$(PLATFORM)'"
	@exit 1
endif
	@$(ECHO_SUBTITLE2) "➔ Testing SCHEME='$(SCHEME1)'"
	set -eo pipefail; \
	xcodebuild -version; \
	xcodebuild -workspace "CPProject.xcworkspace" -destination "platform=$(PLATFORM),name=$(DEVICE),OS=$(OS)" -scheme "$(SCHEME1)" -parallel-testing-enabled NO test | xcbeautify

	@$(ECHO_SUBTITLE2) "➔ Testing SCHEME='$(SCHEME2)'"
	set -eo pipefail; \
	xcodebuild -version; \
	xcodebuild -workspace "CPProject.xcworkspace" -destination "platform=$(PLATFORM),name=$(DEVICE),OS=$(OS)" -scheme "$(SCHEME2)" -parallel-testing-enabled NO test | xcbeautify

