#!/bin/zsh

# Usage:
# $ ./tools/release/validate-version.sh -h 
# Validates SDK and podspec versions against release tag.

# Options:
#   --tag: The tag to validate versions.
#   --artifacts-path: The path to build artifacts.

set -eo pipefail
source ./tools/utils/argparse.sh
source ./tools/utils/echo-color.sh

set_description "Validates SDK and podspec versions against release tag."
define_arg "tag" "" "The tag to validate versions." "string" "true"
define_arg "artifacts-path" "" "The path to build artifacts." "string" "true"

check_for_help "$@"
parse_args "$@"

REPO_PATH="$artifacts_path/dd-openfeature-provider-swift"
SCRIPT_DIRECTORY="${0:A:h}"

python3 "$SCRIPT_DIRECTORY/release_version.py" validate --version "$tag" --root "$REPO_PATH"
