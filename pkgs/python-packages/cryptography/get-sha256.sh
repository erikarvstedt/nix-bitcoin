#! /usr/bin/env nix-shell
#! nix-shell -i bash -p git gnupg
set -euo pipefail

TMPDIR="$(mktemp -d -p /tmp)"
trap "rm -rf $TMPDIR" EXIT
cd $TMPDIR

echo "Fetching latest release"
git clone https://github.com/pyca/cryptography 2> /dev/null
cd cryptography
latest=3.3.2
echo "Latest release is ${latest}"

# GPG verification
export GNUPGHOME=$TMPDIR
echo "Paul Kehrer Key"
gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 05FD9FA16CF757350D91A560235AE5F129F9ED98 2> /dev/null
echo "Verifying latest release"
git verify-tag ${latest}

echo "tag: ${latest}"
# The prefix option is necessary because GitHub prefixes the archive contents in this format
echo "sha256: $(git archive --format tar.gz --prefix="cryptography-${latest}"/ ${latest} | sha256sum | cut -d\  -f1)"
