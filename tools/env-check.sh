#!/bin/zsh

# Usage:
# $ ./tools/env-check.sh
# Prints environment information and checks if required tools are installed.

set -e
source ./tools/utils/echo-color.sh

check_if_installed() {
    if ! command -v $1 >/dev/null 2>&1; then
        echo_err "Error" "$1 is not installed but it is required for development. Install it and try again."
        exit 1
    fi
}

check_if_optional() {
    if ! command -v $1 >/dev/null 2>&1; then
        echo_warning "$1 is not installed (optional)"
        return 1
    fi
    return 0
}

echo_title "Environment Check for dd-openfeature-provider-swift"

echo_subtitle "Check versions of installed tools"

echo_succ "System info:"
system_profiler SPSoftwareDataType

echo ""
echo_succ "Active Xcode:"
check_if_installed xcodebuild
xcode-select -p
xcodebuild -version

echo ""
echo_succ "Other Xcodes:"
ls /Applications/ | grep Xcode || echo "No other Xcode installations found"

echo ""
echo_succ "Swift:"
check_if_installed swift
swift --version

echo ""
echo_succ "SwiftLint:"
check_if_installed swiftlint
swiftlint --version

echo ""
echo_succ "Git:"
check_if_installed git
git --version

echo ""
echo_succ "Homebrew (optional):"
if check_if_optional brew; then
    brew --version
fi

echo ""
echo_succ "xcbeautify (optional):"
if check_if_optional xcbeautify; then
    xcbeautify --version
fi

echo_succ "Environment check completed successfully"
