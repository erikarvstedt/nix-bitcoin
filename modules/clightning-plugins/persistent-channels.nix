{ config, lib, pkgs, ... }:

let cfg = config.services.clightning.plugins.persistentChannels; in

{
  options.services.clightning.plugins.persistentChannels = {
    enable = lib.mkEnableOption "Persistent channels (clightning plugin)";
  };

  config = lib.mkIf cfg.enable {
    services.clightning.extraConfig = "plugin-dir=${config.nix-bitcoin.pkgs.clightning-plugins.persistent-channels}";
  };
}
