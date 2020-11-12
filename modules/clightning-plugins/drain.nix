{ config, lib, pkgs, ... }:

let cfg = config.services.clightning.plugins.drain; in

{
  options.services.clightning.plugins.drain = {
    enable = lib.mkEnableOption "Drain (clightning plugin)";
  };

  config = lib.mkIf cfg.enable {
    services.clightning.extraConfig = "plugin-dir=${config.nix-bitcoin.pkgs.clightning-plugins.drain}";
  };
}
