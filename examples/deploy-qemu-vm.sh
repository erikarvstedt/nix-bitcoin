#!/usr/bin/env bash
set -euo pipefail

# This script demonstrates how to run a nix-bitcoin node in QEMU.
# Running this script leaves no traces on your host system.

# This demo is a template for your own experiments.
# Run with option `--interactive` or `-i` to start a shell for interacting with
# the node.

# MAKE SURE TO REPLACE the SSH identity file if you use this script for
# anything serious.

if [[ ! -v NIX_BITCOIN_EXAMPLES_DIR ]]; then
    echo "Running script in nix shell env..."
    cd "${BASH_SOURCE[0]%/*}"
    exec nix-shell --run "./${BASH_SOURCE[0]##*/} $*"
else
    cd "$NIX_BITCOIN_EXAMPLES_DIR"
fi

source qemu-vm/run-vm.sh

echo "Building VM"
nix-build --out-link $tmpDir/vm - <<'EOF'
(import <nixpkgs/nixos> {
  configuration = {
    imports = [
      <configuration.nix>
      <qemu-vm/vm-config.nix>
    ];
    nix-bitcoin.generateSecrets = true;
  };
}).vm
EOF

vmNumCPUs=8
vmMemoryMiB=4096
sshPort=60734
runVM $tmpDir/vm $vmNumCPUs $vmMemoryMiB $sshPort

vmWaitForSSH
printf "Waiting until services are ready"
echo

case ${1:-} in
    -i|--interactive)
        . start-bash-session.sh
        ;;
esac

# Cleanup happens at exit (defined in qemu-vm/run-vm.sh)
