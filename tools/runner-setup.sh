#!/bin/zsh

# Usage:
# $ ./tools/runner-setup.sh -h
# This script supplements missing components on the runner for dd-openfeature-provider-swift CI.

# Options:
#   --xcode: Specify the Xcode version to activate.
#   --iOS: Install the iOS platform with the latest simulator if not already installed. Default: disabled.
#   --tvOS: Install the tvOS platform with the latest simulator if not already installed. Default: disabled.
#   --watchOS: Install the watchOS platform with the latest simulator if not already installed. Default: disabled.

set -eo pipefail
source ./tools/utils/echo-color.sh

# Initialize variables with defaults (following dd-sdk-ios pattern)
xcode=""
iOS="false"
tvOS="false"
watchOS="false"

# Parse arguments (simplified argparse following dd-sdk-ios pattern)
while [[ $# -gt 0 ]]; do
    case $1 in
        --xcode)
            xcode="$2"
            shift 2
            ;;
        --iOS)
            iOS="true"
            shift
            ;;
        --tvOS)
            tvOS="true"
            shift
            ;;
        --watchOS)
            watchOS="true"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "This script supplements missing components on the runner for dd-openfeature-provider-swift CI."
            echo ""
            echo "Options:"
            echo "  --xcode VERSION    Specify the Xcode version to activate"
            echo "  --iOS              Install the iOS platform with the latest simulator"
            echo "  --tvOS             Install the tvOS platform with the latest simulator"
            echo "  --watchOS          Install the watchOS platform with the latest simulator"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --xcode 16.2.0 --iOS --tvOS"
            exit 0
            ;;
        *)
            echo_err "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

change_xcode_version() {
    local version="$1"

    echo_subtitle "Change Xcode version to: '$version'"
    local XCODE_PATH="/Applications/Xcode-$version.app/Contents/Developer"
    local CURRENT_XCODE_PATH=$(xcode-select -p)

    if [[ "$CURRENT_XCODE_PATH" == "$XCODE_PATH" ]]; then
        echo_succ "Already using Xcode version '$version'."
    elif [[ -d "$XCODE_PATH" ]]; then
        echo "Found Xcode at '$XCODE_PATH'."
        if sudo xcode-select -s "$XCODE_PATH"; then
            echo_succ "Switched to Xcode version '$version'."
        else
            echo_err "Failed to switch to Xcode version '$version'."
            exit 1
        fi
    else
        echo_err "Xcode version '$version' not found at $XCODE_PATH."
        echo "Available Xcode versions:"
        ls /Applications/ | grep Xcode
        exit 1
    fi

    if sudo xcodebuild -license accept; then
        echo_succ "Xcode license accepted."
    else
        echo_err "Failed to accept the Xcode license."
        exit 1
    fi

    if sudo xcodebuild -runFirstLaunch; then
        echo_succ "Installed Xcode packages."
    else
        echo_err "Failed to install Xcode packages."
        exit 1
    fi
}

# Change Xcode version if specified (following dd-sdk-ios pattern)
if [[ -n "$xcode" ]]; then
    change_xcode_version $xcode
fi

echo_succ "Using 'xcodebuild -version':"
xcodebuild -version

# Install platforms if requested (following dd-sdk-ios pattern)
if [ "$iOS" = "true" ]; then
    echo_subtitle "Install iOS platform"
    echo "▸ xcodebuild -downloadPlatform iOS -quiet"
    xcodebuild -downloadPlatform iOS -quiet
fi

if [ "$tvOS" = "true" ]; then
    echo_subtitle "Install tvOS platform"
    echo "▸ xcodebuild -downloadPlatform tvOS -quiet"
    xcodebuild -downloadPlatform tvOS -quiet
fi

if [ "$watchOS" = "true" ]; then
    echo_subtitle "Install watchOS platform"
    echo "▸ xcodebuild -downloadPlatform watchOS -quiet"
    xcodebuild -downloadPlatform watchOS -quiet
fi

# Ensure SwiftLint is available
echo_subtitle "Ensuring SwiftLint is available"
if ! command -v swiftlint >/dev/null 2>&1; then
    echo_warn "SwiftLint not found. Installing via Homebrew..."
    if brew install swiftlint; then
        echo_succ "SwiftLint installed successfully"
    else
        echo_err "Failed to install SwiftLint"
        exit 1
    fi
else
    echo_succ "SwiftLint already available: $(swiftlint version)"
fi

echo_succ "Runner setup completed successfully"
