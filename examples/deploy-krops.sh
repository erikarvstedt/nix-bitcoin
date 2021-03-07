#!/usr/bin/env bash
set -euo pipefail

# This script demonstrates how to setup a nix-bitcoin node with krops.
# Running this script leaves no traces on your host system.

# This demo is a template for your own experiments.
# Feel free to modify or to run nix-shell and execute individual statements of this
# script in the interactive shell.

# MAKE SURE TO REPLACE the SSH identity file if you use this script for
# anything serious.

if [[ ! -v IN_NIX_SHELL ]]; then
    echo "Running script in nix shell env..."
    cd "${BASH_SOURCE[0]%/*}"
    exec nix-shell --run "./${BASH_SOURCE[0]##*/} $*"
fi

cd "${BASH_SOURCE[0]%/*}"

tmpDir=/tmp/nix-bitcoin-krops
mkdir -p $tmpDir

# Cleanup on exit
cleanup() {
    set +eu
    kill -9 $qemuPID
    rm -rf $tmpDir
    rm $node
    rm $nixos_config
}
trap "cleanup" EXIT

identityFile=qemu-vm/id-vm
chmod 0600 $identityFile

echo "Building VM"
nix-build --out-link $tmpDir/vm - <<EOF
(import <nixpkgs/nixos> {
  configuration = {
    virtualisation.graphics = false;
    virtualisation.diskSize = 8192;
    services.mingetty.autologinUser = "root";
    services.openssh.enable = true;
    users.users.root = {
      openssh.authorizedKeys.keys = [ "$(cat $identityFile.pub)" ];
    };
  };
}).vm
EOF

vmMemoryMiB=2048
vmNumCPUs=4
sshPort=50734

export NIX_DISK_IMAGE=$tmpDir/img
export QEMU_NET_OPTS=hostfwd=tcp::$sshPort-:22
</dev/null $tmpDir/vm/bin/run-*-vm -m $vmMemoryMiB -smp $vmNumCPUs &>/dev/null &
qemuPID=$!

# Run command in VM
c() {
    ssh -p $sshPort -i $identityFile -o ConnectTimeout=1 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
        -o ControlMaster=auto -o ControlPath=$tmpDir/ssh-connection -o ControlPersist=60 \
        root@127.0.0.1 "$@"
}

echo
echo "Waiting for SSH connection..."
while ! c : 2>/dev/null; do :; done

nixos_config=$(mktemp)
cat <<EOF > "$nixos_config"
{ config, pkgs, lib, ... }: {
    imports = [
      <nixpkgs/nixos/modules/virtualisation/qemu-vm.nix>
      <nix-bitcoin/examples/configuration.nix>
      <nix-bitcoin/examples/krops/krops-configuration.nix>
    ];
    # Apparmor is enabled through the hardened NixOS profile, but it doesn't
    # work in this VM.
    security.apparmor.enable = false;
    services.openssh.enable = true;
    users.users.root = {
      openssh.authorizedKeys.keys = [ "$(cat $identityFile.pub)" ];
    };
}
EOF

node=$(mktemp)
cat <<EOF > "$node"
let
  extraSources = {
    nixos-config.file = toString $nixos_config;
  };
  common = import $(pwd)/krops/node-common.nix { inherit extraSources; };
  target = common.nixBitcoinPkgs.krops.lib.mkTarget "root@localhost" // {
    port = "$sshPort";
    extraOptions = [
      "-i$identityFile" "-oConnectTimeout=1"
      "-oStrictHostKeyChecking=no" "-oUserKnownHostsFile=/dev/null" "-oLogLevel=ERROR"
      "-oControlMaster=auto" "-oControlPath=$tmpDir/ssh-connection" "-oControlPersist=60"
    ];
  };
in
common.nixBitcoinPkgs.krops.pkgs.krops.writeCommand "deploy" {
  source = common.source;
  inherit target;
  # Avoid having to create the sentinel file
  force = true;
  # Don't "switch" to the config because that would install a bootloader which
  # is not possible in this VM.
  command = targetPath: ''
    nixos-rebuild test -I /var/src
  '';
}
EOF

$(nix-build --no-out-link $node --show-trace)

echo
echo "Waiting until services are ready..."
c '
attempts=300
while ! systemctl is-active clightning &> /dev/null; do
    ((attempts-- == 0)) && { echo "timeout"; exit 1; }
    sleep 0.2
done
'
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

case ${1:-} in
    -i|--interactive)
        . start-bash-session.sh
        ;;
esac

# Cleanup happens at exit (see above)
