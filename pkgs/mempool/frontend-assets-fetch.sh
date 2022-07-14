#!/usr/bin/env bash
set -euo pipefail

# Fetch hash-locked versions of assets that are dynamically fetched via
# https://github.com/mempool/mempool/blob/master/frontend/sync-assets.js
# when running `npm run build` in the frontend.
#
# This file is updated by ./frontend-assets-update.sh

declare -A revs=(
    ["blockstream/asset_registry_db"]=25078a129e2796a850ede0b78b80d26ebeaa4032
    ["mempool/mining-pools"]=439214cbc0fec0aa78b5b7de0bcddf7c9daab7cb
    ["mempool/mining-pool-logos"]=4219bf546590bf5a31a1bf56d6a7250ab62a3351
)

fetchFile() {
    repo=$1
    file=$2
    rev=${revs["$repo"]}
    curl -fsS "https://raw.githubusercontent.com/$repo/$rev/$file"
}

fetchRepo() {
    repo=$1
    rev=${revs["$repo"]}
    curl -fsSL "https://github.com/$repo/archive/$rev.tar.gz"
}

fetchFile "blockstream/asset_registry_db" index.json > assets.json
fetchFile "blockstream/asset_registry_db" index.minimal.json > assets.minimal.json
# shellcheck disable=SC2094
fetchFile "mempool/mining-pools" pools.json > pools.json
mkdir mining-pools
fetchRepo "mempool/mining-pool-logos" | tar xz --strip-components=1 -C mining-pools
