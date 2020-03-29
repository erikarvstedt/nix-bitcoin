#!/usr/bin/env bash

set -e

REPO=fort-nix/nix-bitcoin
GPG_KEY=$1
if [ -z $VERSION ]; then
    VERSION=$(curl --silent "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name' | tail -c +2)
fi

TMP_DIR=$(mktemp -d)
cd $TMP_DIR
BASEURL=https://github.com/jonasnick/nix-bitcoin/releases/download/v$VERSION
curl --silent -L -O $BASEURL/SHA256SUMS.txt
curl --silent -L -O $BASEURL/SHA256SUMS.txt.asc

GPG_HOME=$(mktemp -d)
gpg --homedir $GPG_HOME --import $GPG_KEY &> /dev/null
gpg --homedir $GPG_HOME --verify SHA256SUMS.txt.asc &> /dev/null || {
    echo "Signature verification failed"
    exit 1
}

SHA256=$(cat SHA256SUMS.txt | grep -Eo '^[^ ]+')
cat <<EOF
{
  url = "$BASEURL/nix-bitcoin-$VERSION.tar.gz";
  sha256 = "$SHA256";
}
EOF
cd - &> /dev/null
