{ config, lib, pkgs, ... }:

let cfg = config.services.clightning.plugins.monitor; in

{
  options.services.clightning.plugins.monitor = {
    enable = lib.mkEnableOption "Monitor (clightning plugin)";
  };

  config = lib.mkIf cfg.enable {
    services.clightning.extraConfig = "plugin-dir=${config.nix-bitcoin.pkgs.clightning-plugins.monitor}";
  };
}
