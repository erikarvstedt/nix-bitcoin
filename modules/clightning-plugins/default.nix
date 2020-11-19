{ config, lib, pkgs, ... }:

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
    helpme.enable = lib.mkEnableOption "Help me (clightning plugin)";
    monitor.enable = lib.mkEnableOption "Monitor (clightning plugin)";
    rebalance.enable = lib.mkEnableOption "Rebalance (clightning plugin)";
  };

  config = {
    services.clightning.extraConfig = lib.mkMerge [
      (lib.mkIf cfg.helpme.enable "plugin-dir=${pluginPkgs.helpme}")
      (lib.mkIf cfg.monitor.enable "plugin-dir=${pluginPkgs.monitor}")
      (lib.mkIf cfg.rebalance.enable "plugin-dir=${pluginPkgs.rebalance}")
    ];
  };
}
