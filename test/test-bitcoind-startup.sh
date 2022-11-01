#!/usr/bin/env bash
set -euo pipefail

cd "${BASH_SOURCE[0]%/*}"

tmpDir=/tmp/test-bitcoind-startup
stateDir=$tmpDir/vm-state
rm -rf "$tmpDir"
mkdir -p "$stateDir"

nix build -o "$tmpDir/system" -L ..#tests.default.vm

: ${numRuns:=10}
failures=0

for i in $(seq $numRuns); do
    rm -rf "$stateDir"/*
    NIX_BITCOIN_VM_DATADIR=$stateDir "$tmpDir/system/bin/run-vm-in-tmpdir"
    if [[ $(cat "$stateDir/xchg/result") != success ]]; then
        ((failures+=1))
        echo "nbfailure"
        cat "$stateDir/xchg/bitcoind-journal"
    fi

    echo
    echo "------------------------------------------------------------"
    echo "nbresult: $i runs, $failures failures"
    echo
done
