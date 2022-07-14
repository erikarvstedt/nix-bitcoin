#!/usr/bin/env bash
set -euo pipefail

# Fetch hash-locked versions of assets that are dynamically fetched via
# https://github.com/mempool/mempool/blob/master/frontend/sync-assets.js
# when running `npm run build` in the frontend.

declare -A revs=(
    ["blockstream/asset_registry_db"]=fc47d3b21c32a81617c1e118af06b37fe6cc217b
    ["mempool/mining-pools"]=ef8de0ef7a98bd149b1b791730933da4731051b8
    ["mempool/mining-pool-logos"]=79e4b379561206692ea3a90524d7f78558f638e0
)

fetchFile() {
    repo=$1
    file=$2
    rev=${revs["$repo"]}
    curl -fsS https://raw.githubusercontent.com/$repo/$rev/$file
}

fetchRepo() {
    repo=$1
    rev=${revs["$repo"]}
    curl -fsSL https://github.com/$repo/archive/$rev.tar.gz
}

fetchFile "blockstream/asset_registry_db" index.json > assets.json
fetchFile "blockstream/asset_registry_db" index.minimal.json > assets.minimal.json
fetchFile "mempool/mining-pools" pools.json > pools.json
mkdir mining-pools
fetchRepo "mempool/mining-pool-logos" | tar xz --strip-components=1 -C mining-pools
