{ config, lib, pkgs, ... }:

let cfg = config.services.clightning.plugins.feeadjuster; in

{
  options.services.clightning.plugins.feeadjuster = {
    enable = lib.mkEnableOption "Fee adjuster (clightning plugin)";
    deactivateFuzz = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Deactivate update threshold randomization and hysterisis.";
    };
    threshold = lib.mkOption {
      type = lib.types.str;
      default = "0.05";
      description = "Channel balance update threshold at which to trigger an update. Note it's fuzzed.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.clightning.extraConfig =
      ''
      plugin-dir=${config.nix-bitcoin.pkgs.clightning-plugins.feeadjuster}
      ${lib.optionalString cfg.deactivateFuzz "feeadjuster-deactivate-fuzz"}
      feeadjuster-threshold=${cfg.threshold}
      '';
  };
}
