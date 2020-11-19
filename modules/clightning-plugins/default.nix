{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.clightning.plugins;
  pluginPkgs = config.nix-bitcoin.pkgs.clightning-plugins;
in {
  imports = [
    ./prometheus.nix
    ./summary.nix
    ./zmq.nix
  ];

  options.services.clightning.plugins = {
    helpme.enable = mkEnableOption "Help me (clightning plugin)";
    monitor.enable = mkEnableOption "Monitor (clightning plugin)";
    rebalance.enable = mkEnableOption "Rebalance (clightning plugin)";
  };

  config = {
    services.clightning.extraConfig = mkMerge [
      (mkIf cfg.helpme.enable "plugin-dir=${pluginPkgs.helpme}")
      (mkIf cfg.monitor.enable "plugin-dir=${pluginPkgs.monitor}")
      (mkIf cfg.rebalance.enable "plugin-dir=${pluginPkgs.rebalance}")
    ];
  };
}
