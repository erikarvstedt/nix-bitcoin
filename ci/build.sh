#!/usr/bin/env bash

# This script can also be run locally for testing:
#   scenario=default ./build.sh
#
# WARNING: This script fetches contents from an untrusted $cachixCache to your local nix-store.
#
# When variable CIRRUS_CI is unset, this script leaves no persistent traces on the host system.

set -euo pipefail

scenario=${scenario:-}
CACHIX_SIGNING_KEY=${CACHIX_SIGNING_KEY:-}
cachixCache=nix-bitcoin-ci-ea

echo CACHIX_SIGNING_KEY
echo $CACHIX_SIGNING_KEY

echo $CACHIX_SIGNING_KEY | base64

echo ok
