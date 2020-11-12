{ config, lib, pkgs, ... }:

let cfg = config.services.clightning.plugins.sendinvoiceless; in

{
  options.services.clightning.plugins.sendinvoiceless = {
    enable = lib.mkEnableOption "Send invoice-less (clightning plugin)";
  };

  config = lib.mkIf cfg.enable {
    services.clightning.extraConfig =
      "plugin-dir=${config.nix-bitcoin.pkgs.clightning-plugins.sendinvoiceless}";
  };
}
