{ config, lib, pkgs, ... }:

let cfg = config.services.clightning.plugins.donations; in

{
  options.services.clightning.plugins.donations = {
    enable = lib.mkEnableOption "Donations (clightning plugin)";
    autostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start the server automatically.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 33506;
      description = "Bind the donations webserver to this port.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.clightning.extraConfig =
      ''
      plugin-dir=${config.nix-bitcoin.pkgs.clightning-plugins.donations}
      donation-autostart=${toString cfg.autostart}
      donation-web-port=${toString cfg.port}
      '';
  };
}
