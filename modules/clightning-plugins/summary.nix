{ config, lib, ... }:

with lib;
let cfg = config.services.clightning.plugins.summary; in
{
  options.services.clightning.plugins.summary = {
    enable = mkEnableOption "Summary (clightning plugin)";
    currency = mkOption {
      type = types.str;
      default = "USD";
      description = "What currency should I look up on btcaverage?";
    };
    currencyPrefix = mkOption {
      type = types.str;
      default = "USD $";
      description = "What prefix to use for currency";
    };
    availabilityInterval = mkOption {
      type = types.int;
      default = 300;
      description = "How often in seconds the availability should be calculated.";
    };
    availabilityWindow = mkOption {
      type = types.int;
      default = 72;
      description = "How many hours the availability should be averaged over.";
    };
  };

  config = mkIf cfg.enable {
    services.clightning.extraConfig = ''
      plugin-dir=${config.nix-bitcoin.pkgs.clightning-plugins.summary}
      summary-currency="${cfg.currency}"
      summary-currency-prefix="${cfg.currencyPrefix}"
      summary-availability-interval=${toString cfg.availabilityInterval}
      summary-availability-window=${toString cfg.availabilityWindow}
    '';
  };
}
