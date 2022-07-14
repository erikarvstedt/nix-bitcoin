#!/usr/bin/env nix-shell
#! nix-shell -i bash -p gnupg gnused jq
set -euo pipefail

# Use this to start a debug shell at the location of this statement
# . "${BASH_SOURCE[0]%/*}/../../helper/start-bash-session.sh"

version=
# https://github.com/erikarvstedt/mempool/commits/dev
rev=1b91d3e5d60fedb60eb7b8f57035de3b7082364d
owner=erikarvstedt
repo=https://github.com/$owner/mempool

cd "${BASH_SOURCE[0]%/*}"

updateRepo() {
    TMPDIR="$(mktemp -d /tmp/mempool.XXX)"
    trap "rm -rf $TMPDIR" EXIT

    # Fetch and verify source
    src=$TMPDIR/src
    mkdir -p $src
    if [[ -v rev ]]; then
        git -C $src init
        git -C $src fetch --depth 1 $repo $rev:src
        git -C $src checkout src
        version=$rev
    else
        # Fetch version tag
        git clone --depth 1 --branch $version -c advice.detachedHead=false $repo $src
        git -C $src checkout tags/$version
        export GNUPGHOME=$TMPDIR
        gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 913C5FF1F579B66CA10378DBA394E332255A6173 2> /dev/null
        git -C $src verify-tag $version
    fi
    rm -rf $src/.git
    hash=$(nix hash path $src)

    sed -i "
      s|\bowner = .*;|owner = \"$owner\";|
      s|\brev = .*;|rev = \"$version\";|
      s|\bhash = .*;|hash = \"$hash\";|
    " default.nix
}
updateNodeModulesHash() {
    component=$1
    echo
    echo "Fetching node modules for mempool-$component"
    updateFixedOutputDirevation ./default.nix mempool-$component "cd $component"
}
updateFixedOutputDirevation() {
    # The file that defines the derivation that should be updated
    file=$1
    # The output name of this flake that should be updated
    flakeOutput=$2
    # A pattern in a line preceding the hash that should be updated
    patternPrecedingHash=$3

    sed -i "/$patternPrecedingHash/,/hash/ s|hash = .*|hash = \"\";|" $file
    # Display stderr and capture it. stdbuf is required to disable output buffering.
    stderr=$(
        nix build --no-link -L .#$flakeOutput |&
        stdbuf -oL grep -v '\berror:.*failed to build$' |
        tee /dev/stderr || :
    )
    hash=$(echo "$stderr" | sed -nE 's/.*?\bgot: *?(sha256-.*)/\1/p')
    if [[ ! $hash ]]; then
        echo
        echo "Error: No hash in build output."
        exit 1
    fi
    sed -i "/$patternPrecedingHash/,/hash/ s|hash = .*|hash = \"$hash\";|" $file
}
updateFrontendAssets() {
  . ./frontend-assets-update.sh
  echo
  echo "Fetching frontend assets"
  updateFixedOutputDirevation ./default.nix mempool-frontend.assets "frontendAssets"
}

if [[ $# == 0 ]]; then
    # Each of these can be run separately
    updateRepo
    updateFrontendAssets
    updateNodeModulesHash backend
    updateNodeModulesHash frontend
else
    eval "$@"
fi
