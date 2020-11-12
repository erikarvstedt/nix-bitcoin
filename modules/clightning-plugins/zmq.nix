{ config, lib, pkgs, ... }:

let cfg = config.services.clightning.plugins.zmq; in

{
  options.services.clightning.plugins.zmq = {
    enable = lib.mkEnableOption "ZMQ (clightning plugin)";
  };

  config = lib.mkIf cfg.enable {
    services.clightning.extraConfig =
      "plugin-dir=${config.nix-bitcoin.pkgs.clightning-plugins.zmq}";
  };
}
