{ config, lib, ... }:

let
  cfg = config.services.clightning.plugins.zmq;

  endpoints = [
    "channel-opened"
    "connect"
    "disconnect"
    "invoice-payment"
    "warning"
    "forward-event"
    "sendpay-success"
    "sendpay-failure"
  ];

  mkEndpointOption = name: {
    inherit name;
    value = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Endpoint for ${name}";
    };
  };

  mkEndpointLine = n:
    let ep = builtins.getAttr n cfg; in
    lib.optionalString (ep != null) ''
      zmq-pub-${n}=${ep}
    '';
in
{
  options.services.clightning.plugins.zmq = {
    enable = lib.mkEnableOption "ZMQ (clightning plugin)";
  } // builtins.listToAttrs (map mkEndpointOption endpoints);

  config = lib.mkIf cfg.enable {
    services.clightning.extraConfig = ''
      plugin-dir=${config.nix-bitcoin.pkgs.clightning-plugins.zmq}
      ${lib.concatStrings (map mkEndpointLine endpoints)}
    '';
  };
}
