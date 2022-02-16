#!/usr/bin/env nix-shell
#! nix-shell -i bash -p nodePackages.node2nix gnupg wget jq gnused nix_2_4
set -euo pipefail

# Use this to start a debug shell at the location of this statement
# . "${BASH_SOURCE[0]%/*}/../../helper/start-bash-session.sh"

repo=https://github.com/mempool/mempool

TMPDIR="$(mktemp -d /tmp/mempool.XXX)"
trap "rm -rf $TMPDIR" EXIT

rev=v2.3.1
# Fetch source
src=$TMPDIR/src
mkdir -p $src
curl -SL https://github.com/mempool/mempool/archive/${rev}.tar.gz | tar xz --strip-components=1 -C $src

hash=$(nix hash path $src)

generatePkg() {
  component=$1
  node2nix \
    --input $src/$component/package.json \
    --lock $src/$component/package-lock.json \
    --output node-packages-$component.nix \
    --composition /dev/null \
    --no-copy-node-env

  # Delete reference to temporary src
  sed -i '/\bsrc = .*\/tmp\/mempool/d' node-packages-$component.nix
}

generatePkg frontend
generatePkg backend

# Use the verified package src
sed -i "
  s|\brev = .*;|rev = \"${rev}\";|
  s|\hash = .*;|hash = \"${hash}\";|
" default.nix
