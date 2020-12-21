{ config, lib, pkgs, ... }:

with lib;
let cfg = config.services.clightning.plugins.clboss; in
{
  options.services.clightning.plugins.clboss = {
    enable = mkEnableOption "CLBOSS (clightning plugin)";
    min-onchain = mkOption {
      type = types.ints.positive;
      default = 30000;
      description = ''
        Specify target amount that CLBOSS will leave onchain
      '';
    };
    torify = mkOption {
    # needs custom wrapper because torsocks doesn't honor global settings
    # https://github.com/NixOS/nixpkgs/issues/94236
      readOnly = true;
      default = pkgs.writeScriptBin "torify"''
        ${pkgs.tor}/bin/torify \
        --address ${toString (head (splitString ":" config.services.tor.client.socksListenAddress))} \
        "$@"
      '';
    };
  };

  config = mkIf cfg.enable {
    services.clightning.extraConfig = ''
      plugin=${config.nix-bitcoin.pkgs.clboss}/bin/clboss
      clboss-min-onchain=${toString cfg.min-onchain}
    '';
    systemd.services.clightning.path =[
      pkgs.dnsutils
    ] ++ optional config.services.clightning.enforceTor (hiPrio cfg.torify);
  };
}
