{ config, lib, pkgs, ... }:

let cfg = config.services.clightning.plugins.jitrebalance; in

{
  options.services.clightning.plugins.jitrebalance = {
    enable = lib.mkEnableOption "JIT rebalance (clightning plugin)";
    timeout = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Number of seconds before we stop trying to rebalance a channel.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.clightning.extraConfig =
      ''
      plugin-dir=${config.nix-bitcoin.pkgs.clightning-plugins.jitrebalance}
      jitrebalance-try-timeout=${toString cfg.timeout}
      '';
  };
}
