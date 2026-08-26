#!/bin/zsh

# Publishes a GitHub Release for an existing, validated tag.

# ENVs:
# - DRY_RUN: Set to '1' to validate and render notes without publishing.

set -eo pipefail
source ./tools/utils/argparse.sh
source ./tools/utils/echo-color.sh

set_description "Publishes a GitHub Release for an existing release tag."
define_arg "tag" "" "The release tag to publish." "string" "true"

check_for_help "$@"
parse_args "$@"

REPO_NAME="DataDog/dd-openfeature-provider-swift"
REPO_ROOT="$(pwd)"
SCRIPT_DIRECTORY="${0:A:h}"
RELEASE_NOTES_PATH="$(mktemp)"
TOKEN_ACQUIRED="false"
DRY_RUN="${DRY_RUN:-1}"

cleanup() {
    rm -f "$RELEASE_NOTES_PATH"
    if [[ "$TOKEN_ACQUIRED" == "true" ]]; then
        dd-octo-sts --disable-tracing revoke >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

python3 "$SCRIPT_DIRECTORY/release_version.py" validate --version "$tag" --root "$REPO_ROOT"
python3 "$SCRIPT_DIRECTORY/release_version.py" notes \
    --version "$tag" \
    --root "$REPO_ROOT" \
    --output "$RELEASE_NOTES_PATH"

if [[ "$DRY_RUN" == "1" || "$DRY_RUN" == "true" ]]; then
    echo_warn "DRY RUN mode:" "Validated '$tag' and rendered its GitHub release notes."
    exit 0
fi

export GITHUB_TOKEN=$(dd-octo-sts --disable-tracing token \
    --scope "$REPO_NAME" \
    --policy self.gitlab.release.create-release)
TOKEN_ACQUIRED="true"

if gh release view "$tag" --repo "$REPO_NAME" >/dev/null 2>&1; then
    is_draft=$(gh release view "$tag" --repo "$REPO_NAME" --json isDraft --jq .isDraft)
    if [[ "$is_draft" == "true" ]]; then
        gh release edit "$tag" \
            --repo "$REPO_NAME" \
            --verify-tag \
            --draft=false \
            --title "$tag" \
            --notes-file "$RELEASE_NOTES_PATH"
        echo_succ "Published existing draft GitHub Release '$tag'."
    else
        echo_succ "GitHub Release '$tag' is already published. Skipping."
    fi
else
    gh release create "$tag" \
        --repo "$REPO_NAME" \
        --verify-tag \
        --title "$tag" \
        --notes-file "$RELEASE_NOTES_PATH"
    echo_succ "Published GitHub Release '$tag'."
fi
