{ config, lib, pkgs, ... }:

let cfg = config.services.clightning.plugins.rebalance; in

{
  options.services.clightning.plugins.rebalance = {
    enable = lib.mkEnableOption "Rebalance (clightning plugin)";
  };

  config = lib.mkIf cfg.enable {
    services.clightning.extraConfig =
      "plugin-dir=${config.nix-bitcoin.pkgs.clightning-plugins.rebalance}";
  };
}
