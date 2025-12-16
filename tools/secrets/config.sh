#!/bin/zsh

DD_VAULT_ADDR=https://vault.us1.ddbuild.io

# The common path prefix for all dd-openfeature-provider-swift secrets in Vault.
#
# When using `vault kv put` to write secrets to a specific path, Vault overwrites the entire set of secrets
# at that path with the new data. This means that any existing secrets at that path are replaced by the new
# secrets. For simplicity, we store each secret independently by writing each to a unique path.
DD_OPENFEATURE_SECRETS_PATH_PREFIX='kv/aws/arn:aws:iam::486234852809:role/ci-dd-openfeature-provider-swift/'

# Secrets needed for release process only
DD_OPENFEATURE_SECRET__CP_TRUNK_TOKEN="cocoapods.trunk.token"

idx=0
declare -A DD_OPENFEATURE_SECRETS
DD_OPENFEATURE_SECRETS[$((idx++))]="$DD_OPENFEATURE_SECRET__CP_TRUNK_TOKEN | Cocoapods token to authenticate 'pod trunk' operations (https://guides.cocoapods.org/terminal/commands.html)"

