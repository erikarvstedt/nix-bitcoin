{ config, lib, ... }:

with lib;
let cfg = config.services.clightning.plugins.feeadjuster; in
let maybeFlag = enable: flag: if enable then flag + "\n" else ""; in
{
  options.services.clightning.plugins.feeadjuster = {
    enable = mkEnableOption "Feeaduster (clightning plugin)";
    fuzz = mkOption {
      type = types.bool;
      default = true;
      description = "Enable update threshold randomization and hysterisis";
    };
    adjustOnForward = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically update fees on forward events";
    };
    method = mkOption {
      type = types.enum [ "soft" "default" "hard" ];
      default = "default";
      description = "Adjustment method to calculate channel fee (soft=less difference, hard=high difference)";
    };
  };

  config = mkIf cfg.enable {
    services.clightning.extraConfig = ''
      plugin=${config.nix-bitcoin.pkgs.clightning-plugins.feeadjuster.path}
      feeadjuster-adjustment-method="${cfg.method}"
    '' +
    (maybeFlag (!cfg.fuzz) "feeadjuster-deactivate-fuzz") +
    (maybeFlag (!cfg.adjustOnForward) "feeadjuster-deactivate-fee-update");
  };
}
