#!/usr/bin/env bash
set -euo pipefail

cd "${BASH_SOURCE[0]%/*}"

if [[ ${1:-} == vm ]]; then
    # Build VM test
    nix build -L --impure --expr '((import <nixpkgs> {}).callPackage ./. {}).test' --no-link --json
    exit 0
fi

# Build app (using the go build cache) and run test locally (via sudo)
# This is useful for quickly iterating while developing.
# The nix pkg (./default.nix) builds the same test, but in a VM.

binDir=/tmp/setup-dirs-test/bin
mkdir -p $binDir
go build -o $binDir/setup-dirs ./setup-dirs.go
export PATH=$binDir:$PATH
export SETUP_DIRS_TEST_USER=nobody
sudo -E ./test.sh
