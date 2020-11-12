{ config, lib, pkgs, ... }:

let cfg = config.services.clightning.plugins.probe; in

{
  options.services.clightning.plugins.probe = {
    enable = lib.mkEnableOption "Probe (clightning plugin)";
    interval = lib.mkOption {
      type = lib.types.int;
      default = 3600;
      description = "How many seconds should we wait between probes?";
    };
    exclusionDuration = lib.mkOption {
      type = lib.types.int;
      default = 1800;
      description = "How many seconds should temporarily failed channels be excluded?";
    };
  };

  config = lib.mkIf cfg.enable {
    services.clightning.extraConfig =
      ''
      plugin-dir=${config.nix-bitcoin.pkgs.clightning-plugins.probe}
      probe-interval=${toString cfg.interval}
      probe-exclusion-duration=${toString cfg.exclusionDuration}
      '';
  };
}
