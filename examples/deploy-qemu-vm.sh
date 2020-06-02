#!/usr/bin/env bash
set -euo pipefail

# This script demonstrates how to run a nix-bitcoin node in QEMU.
# Running this script leaves no traces on your host system.

# This demo is a template for your own experiments.
# Feel free to modify or to run nix-shell and execute individual statements of this
# script in the interactive shell.

# MAKE SURE TO REPLACE the SSH identity file if you use this script for
# anything serious.

if [[ ! -v IN_NIX_SHELL ]]; then
    echo "Running script in nix shell env..."
    exec nix-shell --run "${BASH_SOURCE[0]}"
fi

scriptDir=$(cd "${BASH_SOURCE[0]%/*}" && pwd)
source "$scriptDir/qemu-vm/run-vm.sh"

echo "Building VM"
nix-build --out-link $tmpDir/vm - <<'EOF'
(import <nixpkgs/nixos> {
  configuration = {
    imports = [
      <configuration.nix>
      <qemu-vm/vm-config.nix>
      <nix-bitcoin/modules/secrets/generate-secrets.nix>
    ];
  };
}).vm
EOF

vmNumCPUs=4
vmMemoryMiB=2048
sshPort=60734
runVM $tmpDir/vm $vmNumCPUs $vmMemoryMiB $sshPort

vmWaitForSSH
printf "Waiting until services are ready"
c '
attempts=60
while ! systemctl is-active clightning &> /dev/null; do
    ((attempts-- == 0)) && { echo "timeout"; exit 1; }
    printf .
    sleep 1
done
'
echo

echo
echo "Bitcoind service:"
c systemctl status bitcoind
echo
echo "Bitcoind network:"
c bitcoin-cli getnetworkinfo
echo
echo "lightning-cli state:"
c lightning-cli getinfo
echo
echo "Node info:"
c nodeinfo

# Uncomment to start a shell session here
# bash -li

# Cleanup happens at exit (see above)
