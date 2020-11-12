# FIXME the autopilot plugin immediately dies after start

{ config, lib, pkgs, ... }:

let cfg = config.services.clightning.plugins.autopilot; in

{
  options.services.clightning.plugins.autopilot = {
    enable = lib.mkEnableOption "Autopilot (clightning plugin)";
    numChannels = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = "How many channels should the autopilot aim for (including manually opened channels)?";
    };
    percent = lib.mkOption {
      type = lib.types.int;
      default = 75;
      description = "What percentage of funds should be under the autopilots control? You may not want the autopilot to manage all of your funds, in case you still want to manually open a channel. This parameter limits the amount the plugin will use to manage its own channels.";
    };
    minSize = lib.mkOption {
      type = lib.types.int;
      default = 100000000;
      description = "Minimum channel size to open (msat). The plugin will never open channels smaller than this amount.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.clightning.extraConfig =
      ''
      plugin-dir=${config.nix-bitcoin.pkgs.clightning-plugins.autopilot}
      autopilot-percent=${toString cfg.percent}
      autopilot-num-channels=${toString cfg.numChannels}
      autopilot-min-channel-size-msat=${toString cfg.minSize}
      '';
  };
}
