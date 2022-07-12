#!/usr/bin/env nix-shell
#! nix-shell -i bash -p nodePackages.node2nix gnupg wget jq gnused nix_2_4
set -euo pipefail

# Use this to start a debug shell at the location of this statement
# . "${BASH_SOURCE[0]%/*}/../../helper/start-bash-session.sh"

repo=https://github.com/erikarvstedt/mempool

TMPDIR="$(mktemp -d /tmp/mempool.XXX)"
trap "rm -rf $TMPDIR" EXIT

# https://github.com/erikarvstedt/mempool/commits/dev
version=8924873bfde2b9c2bd218e77800eff4008bd0122
# Fetch and verify source
src=$TMPDIR/src
mkdir -p $src
git -C $src init
git -C $src fetch --depth 1 $repo $version:src
git -C $src checkout src
# This commit was only signed by the Github webinterface
# export GNUPGHOME=$TMPDIR
# gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 913C5FF1F579B66CA10378DBA394E332255A6173 2> /dev/null
# git -C $src verify-tag ${version}
rm -rf $src/.git
hash=$(nix hash path $src)

generatePkg() {
  component=$1
  node2nix \
    --nodejs-16 \
    --input $src/$component/package.json \
    --lock $src/$component/package-lock.json \
    --output node-packages-$component.nix \
    --composition /dev/null \
    --strip-optional-dependencies \
    --no-copy-node-env

  # Delete reference to temporary src
  sed -i '/\bsrc = .*\/tmp\/mempool/d' node-packages-$component.nix
}

generatePkg frontend
generatePkg backend

# Use the verified package src
sed -i "
  s|\brev = .*;|rev = \"${version}\";|
  s|\hash = .*;|hash = \"${hash}\";|
" default.nix
