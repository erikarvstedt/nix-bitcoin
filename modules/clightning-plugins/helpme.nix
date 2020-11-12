{ config, lib, pkgs, ... }:

let cfg = config.services.clightning.plugins.helpme; in

{
  options.services.clightning.plugins.helpme= {
    enable = lib.mkEnableOption "Help me (clightning plugin)";
  };

  config = lib.mkIf cfg.enable {
    services.clightning.extraConfig =
      "plugin-dir=${config.nix-bitcoin.pkgs.clightning-plugins.helpme}";
  };
}
