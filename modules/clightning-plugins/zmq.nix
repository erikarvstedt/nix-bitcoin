{ config, lib, ... }:

with lib;
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
    value = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Endpoint for ${name}";
    };
  };

  mkEndpointLine = n:
    let ep = builtins.getAttr n cfg; in
    optionalString (ep != null) ''
      zmq-pub-${n}=${ep}
    '';
in
{
  options.services.clightning.plugins.zmq = {
    enable = mkEnableOption "ZMQ (clightning plugin)";
  } // builtins.listToAttrs (map mkEndpointOption endpoints);

  config = mkIf cfg.enable {
    services.clightning.extraConfig = ''
      plugin=${config.nix-bitcoin.pkgs.clightning-plugins.zmq.path}
      ${concatStrings (map mkEndpointLine endpoints)}
    '';
  };
}
