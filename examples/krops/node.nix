let
  # FIXME
  target = "root@NODE_SSH_HOST_OR_IP_ADDRESS_OR_HOST_NAME_HERE";
  extraSources = {
    nixos-config.file = toString ../configuration.nix;
    "hardware-configuration.nix".file = toString ../hardware-configuration.nix;
  };
  common = import ./node-common.nix { inherit extraSources; };
in
common.nixBitcoinPkgs.krops.pkgs.krops.writeDeploy "deploy" {
  source = common.source;
  inherit target;
  # Avoid having to create the sentinel file
  force = true;
}
