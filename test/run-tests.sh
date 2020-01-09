#!/usr/bin/env bash

# Modules integration test runner.
# The test (./test.nix) uses the NixOS testing framework and is executed in a VM.
#
# Usage:
#   ./run-tests.sh
#
#   For interactive test debugging, run:
#   ./run-tests.sh debug
#
#   This starts the testing VM and drops you into a Python REPL where you can
#   manually execute the tests from ./test-script.py

set -eo pipefail

numCPUs=${numCPUs:-$(nproc)}
# Min. 800 MiB needed to avoid 'out of memory' errors
memoryMiB=${memoryMiB:-2048}

scriptDir=$(cd "${BASH_SOURCE[0]%/*}" && pwd)

getPkgsSrc() {
    nix eval --raw -f "$scriptDir/../pkgs/nixpkgs-pinned.nix" $1
}
export NIX_PATH=nixpkgs=$(getPkgsSrc nixpkgs):nixpkgs-unstable=$(getPkgsSrc nixpkgs-unstable)

# Run the test. No temporary files are left on the host system.
run() {
    # TMPDIR is also used by the test driver for VM tmp files
    export TMPDIR=$(mktemp -d -p /tmp nix-bitcoin-test.XXXXXX)
    trap "rm -rf $TMPDIR" EXIT

    nix-build --out-link $TMPDIR/driver "$scriptDir/test.nix" -A driver

    # Variable 'tests' contains the Python code that is executed by the driver on startup
    if [[ $interactive ]]; then
        echo "Running interactive testing environment"
        export tests=$(
            echo 'is_interactive = True'
            # ./test-script.py raises an error when 'is_interactive' is defined so
            # that it just loads the initial helper functions and stops before
            # executing the actual tests
            echo 'try:'
            echo '    exec(os.environ["testScript"])'
            echo 'except:'
            echo '    pass'
            echo 'start_all()'
            # drop into REPL
            echo 'import code'
            echo 'code.interact(local=globals())'
        )
    else
        export tests='exec(os.environ["testScript"])'
    fi

    echo "VM stats: CPUs: $numCPUs, memory: $memoryMiB MiB"
    QEMU_NET_OPTS='restrict=on' \
    QEMU_OPTS="-smp $numCPUs -m $memoryMiB -nographic $QEMU_OPTS" \
    $TMPDIR/driver/bin/nixos-test-driver
}

debug() {
    interactive=1
    run
}

# Run the test in a nix derivation
runWithNixBuild() {
    vmTestNixExpr | nix-build --no-out-link -
}

# On continuous integration nodes there are few other processes running alongside the
# test, so use more memory here for maximum performance.
exprForCI() {
    memoryMiB=3072
    memTotalKiB=$(awk '/MemTotal/ { print $2 }' /proc/meminfo)
    memAvailableKiB=$(awk '/MemAvailable/ { print $2 }' /proc/meminfo)
    # Round down to nearest multiple of 50 MiB for improved test build caching
    ((memAvailableMiB = memAvailableKiB / (1024 * 50) * 50))
    ((memAvailableMiB < memoryMiB)) && memoryMiB=$memAvailableMiB
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

eval "${@:-run}"
