{ config, lib, ... }:

let cfg = config.services.clightning.plugins.prometheus; in
{
  options.services.clightning.plugins.prometheus = {
    enable = lib.mkEnableOption "Prometheus (clightning plugin)";
    listen = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0:9750";
      description = "Address and port to bind to";
    };
  };

  config = lib.mkIf cfg.enable {
    services.clightning.extraConfig = ''
      plugin-dir=${config.nix-bitcoin.pkgs.clightning-plugins.prometheus}
      prometheus-listen=${cfg.listen}
    '';
  };
}
