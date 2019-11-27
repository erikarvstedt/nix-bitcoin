#!/usr/bin/env bash

set -eo pipefail

scriptDir=$(cd "${BASH_SOURCE[0]%/*}" && pwd)

export NIX_PATH=nixpkgs=$(nix eval --raw -f "$scriptDir/../pkgs/nixpkgs-pinned.nix" nixpkgs)

numCPUs=${numCPUs:-$(nproc)}
# Min. 800 MiB needed to avoid 'out of memory' errors
memoryMiB=${memoryMiB:-2048}

run() {
    # TMPDIR is also used by the driver for VM tmp files
    export TMPDIR=$(mktemp -d -p /tmp)
    trap "rm -rf $TMPDIR" EXIT

    nix-build --out-link $TMPDIR/driver "$scriptDir/test.nix" -A driver

    echo "VM stats: CPUs: $numCPUs, memory: $memoryMiB MiB"
    QEMU_NET_OPTS='restrict=on' \
    QEMU_OPTS="-smp $numCPUs -m $memoryMiB -nographic $QEMU_OPTS" \
    tests='eval $ENV{testScript}; die $@ if $@;' \
    $TMPDIR/driver/bin/nixos-test-driver
}

runWithNixBuild() {
    nix-build --no-out-link -E "$vmTestNixExpr"
}

exprForCI() {
    memoryMiB=3072
    memTotalKiB=$(awk '/MemTotal/ { print $2 }' /proc/meminfo)
    memAvailableKiB=$(awk '/MemAvailable/ { print $2 }' /proc/meminfo)
    # Round down to nearest multiple of 50 MiB for improved test build caching
    ((memAvailableMiB = memAvailableKiB / (1024 * 50) * 50))
    ((memAvailableMiB < memoryMiB)) && memoryMiB=$memAvailableMiB
    ((memAvailableMiB < memoryMiB)) && ((memoryMiB = memAvailableMiB))
    >&2 echo "Host memory: total $((memTotalKiB / 1024)) MiB, available $memAvailableMiB MiB, VM $memoryMiB MiB"
    vmTestNixExpr
}

vmTestNixExpr() {
  cat <<EOF
    (import "$scriptDir/test.nix" {}).overrideAttrs (old: rec {
      buildCommand = ''
        export QEMU_OPTS="-smp $numCPUs -m $memoryMiB"
        echo "VM stats: CPUs: $numCPUs, memory: $memoryMiB MiB"
      '' + old.buildCommand;
    })
EOF
}

eval "${1:-run}"
