let
  # FIXME
  target = "root@NODE_SSH_HOST_OR_IP_ADDRESS_OR_HOST_NAME_HERE";

  pkgs = import <nixpkgs> {};
  nixBitcoinPkgs = import <nix-bitcoin> {};
  source = nixBitcoinPkgs.krops.lib.evalSource [{
    nixpkgs.file = {
      path = toString <nixpkgs>;
      useChecksum = true;
    };
    nix-bitcoin.file = {
      path = toString <nix-bitcoin>;
      useChecksum = true;
    };
    "krops-configuration.nix".file = toString ./krops-configuration.nix;
    "hardware-configuration.nix".file = toString ../hardware-configuration.nix;
    nixos-config.file = toString ../configuration.nix;
    secrets.file = toString ../secrets;
  }];
in
nixBitcoinPkgs.krops.pkgs.krops.writeDeploy "deploy" {
  inherit source;
  inherit target;
  # Avoid having to create the sentinel file
  force = true;
}
