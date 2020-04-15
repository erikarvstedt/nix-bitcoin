#! /usr/bin/env nix-shell
#! nix-shell -i bash -p git gnupg
set -e

# Creating temporary directory
echo "Creating temporary directory"
DIR="$(mktemp -d)"
cd $DIR
git clone https://github.com/romanz/electrs 2> /dev/null

# Checking out latest release
echo "Checking out latest release"
cd electrs
latesttagelectrs=$(git describe --tags `git rev-list --tags --max-count=1`)
echo "Latest release is ${latesttagelectrs}"

# GPG Verification
export GNUPGHOME=$DIR
gpg2 --fetch-key https://keybase.io/romanz/pgp_keys.asc?fingerprint=15c8c3574ae4f1e25f3f35c587cae5fa46917cbb 
echo "Verifying latest release"
git verify-tag ${latesttagelectrs}

# Calculating sha256
# The prefix option is necessary because GitHub prefixes the archive contents in this format
echo "sha256 for ${latesttagelectrs} is $(git archive --format tar.gz --prefix=electrs-"${latesttagelectrs//v}"/ ${latesttagelectrs} | sha256sum )"
