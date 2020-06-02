#!/usr/bin/env bash
set -euo pipefail

# This script demonstrates how to setup a nix-bitcoin node with krops.
# The node is deployed on a minimal NixOS QEMU VM.
# Running this script leaves no traces on your host system.

# This demo is a template for your own experiments.
# Feel free to modify or to run nix-shell and execute individual statements of this
# script in the interactive shell.

if [[ ! -v IN_NIX_SHELL ]]; then
    echo "Running script in nix shell env..."
    exec nix-shell --run "${BASH_SOURCE[0]}"
fi

source qemu-vm/run-vm.sh

echo "Building VM"
nix-build --out-link $tmpDir/vm - <<'EOF'
(import <nixpkgs/nixos> {
  configuration = {
    imports = [ <qemu-vm/vm-config.nix>  ];
    services.openssh.enable = true;

    # Add some options from <nixpkgs/nixos/modules/profiles/hardened.nix>
    # to avoid failures when activating the final node config.
    security.apparmor.enable = true;
    nix.allowedUsers = [ "@users" ];
  };
}).vm
EOF

vmNumCPUs=4
vmMemoryMiB=2048
sshPort=60734
runVM $tmpDir/vm $vmNumCPUs $vmMemoryMiB $sshPort

export sshPort
nix-build --out-link $tmpDir/krops-deploy - <<'EOF'
let
  krops = /home/main/s/krops;

  lib = import "${krops}/lib";
  pkgs = import "${krops}/pkgs" {};

  source = lib.evalSource [{
    # WARNING! Set this to a self-contained source in a real deployment.
    # This only works here because /nix/store is shared with the target VM.
    # See the krops manual for an example.
    nixpkgs.symlink = toString <nixpkgs>;

    nixos-config.file = toString <krops-vm-config.nix>;
    nix-bitcoin.file = srcWithoutGit <nix-bitcoin>;
    "configuration.nix".file = toString <configuration.nix>;
    qemu-vm.file = toString <qemu-vm>;

    # WARNING! Be sure that your local secrets dir has permissions 700.
    # Because krops always copies the permissions on deployment,
    # non-user access to the secrets dir would leak the secrets
    # on the target host.
    secrets.file = toString <secrets>;
  }];

  srcWithoutGit = path: {
    path = toString path;
    filters = lib.singleton {
      type = "exclude";
      pattern = ".git";
    };
  };
in
  pkgs.krops.writeDeploy "deploy" {
    # WARNING! Use the default action ("switch") in a real deployment.
    # "test" is only used here because "switch" would install a bootloader which is
    # not possible in our demo VM.
    action = "test";

    inherit source;
    force = true;
    fast = true;
    target = {
      user = "root";
      host = "127.0.0.1";
      port = builtins.getEnv "sshPort";
      # WARNING! Remove 'extraOptions' in a real deployment.
      extraOptions = [
        "-i" (toString <qemu-vm/id-vm>)
        "-oStrictHostKeyChecking=no"
        "-oUserKnownHostsFile=/dev/null"
        "-oLogLevel=ERROR"
      ];
    };
  }
EOF

# Pre-build the system outside of the VM to save some time
nix-build --out-link $tmpDir/store-paths -E '
let
  system = (import <nixpkgs/nixos> { configuration = <krops-vm-config.nix>; }).system;
  pkgsUnstable = (import <nix-bitcoin/pkgs/nixpkgs-pinned.nix>).nixpkgs-unstable;
  pkgs = import <nixpkgs> {};
in
  pkgs.closureInfo { rootPaths = [ system pkgsUnstable ]; }
'
vmWaitForSSH
# Add the store paths to the nix store db on the target host
c "nix-store --load-db < $(realpath $tmpDir/store-paths)/registration"

echo
echo "Deploy with krops"
$tmpDir/krops-deploy

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

# Cleanup happens at exit (defined in qemu-vm/run-vm.sh)
