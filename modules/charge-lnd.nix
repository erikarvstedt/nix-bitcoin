{ config, lib, pkgs, ... }:

with lib;

let
  nbLib = config.nix-bitcoin.lib;
  cfg = config.services.charge-lnd;
  pkg = pkgs.callPackage ../pkgs/charge-lnd.nix { };
  user = "charge-lnd";
  group = "charge-lnd";
  dataDir = "/var/lib/charge-lnd";
  mkValue = value:
    if isBool value then (if value then "true" else "false")
    else if isList value then (concatMapStringsSep ", " toString value)
    else toString value;
  mkKeyValue = k: v: "${k} = ${mkValue v}\n";
  formatPolicy = pol: ''
    [${pol.name}]
    ${strings.concatStrings (attrsets.mapAttrsToList mkKeyValue (builtins.removeAttrs pol [ "name" ]))}
  '';
  configStr = strings.concatMapStringsSep "\n" formatPolicy cfg.policies;
in
{
  options.services.charge-lnd = with types; {
    enable = mkEnableOption "charge-lnd, policy-based fee manager";

    extraFlags = mkOption {
      type = listOf str;
      default = [];
      example = [ "--verbose" "--dry-run" ];
      description = "Extra flags to pass to the charge-lnd command.";
    };

    interval = mkOption {
      type = str;
      default = "*-*-* 04:00:00";
      example = "hourly";
      description = ''
        Systemd calendar expression when to adjust fees. See
        <citerefentry><refentrytitle>systemd.time</refentrytitle>
        <manvolnum>7</manvolnum></citerefentry>.

        Default is once a day.
      '';
    };

    randomizedDelaySec = mkOption {
      type = str;
      default = "1h";
      description = ''
        Random delay to add to scheduled time.
      '';
    };

    policies = mkOption {
      type = listOf attrs;
      default = [];
      example = literalExample ''
        [
          {
            name = "discourage-routing-out-of-balance";
            "chan.max_ratio" = 0.1;
            "chan.min_capacity" = 250000;
            strategy = "static";
            base_fee_msat = 10000;
            fee_ppm = 1000;
          }
          {
            name = "encourage-routing-to-balance";
            "chan.min_ratio" = 0.9;
            "chan.min_capacity" = 250000;
            strategy = "static";
            base_fee_msat = 1;
            fee_ppm = 20;
          }
          {
            name = "default";
            strategy = "ignore";
          }
        ]
      '';
      description = ''
        List of policies evaluated for each channel. Each policy must have a name attribute.
        Policy named `default` will be applied if no other policy matches.

        See https://github.com/accumulator/charge-lnd/blob/master/README.md#usage
        for possible properties and parameters.
      '';
    };

  };

  config = mkIf cfg.enable {
    services.lnd.macaroons.charge-lnd = {
      user = user;
      permissions = ''{"entity":"info","action":"read"},{"entity":"onchain","action":"read"},{"entity":"offchain","action":"read"},{"entity":"offchain","action":"write"}'';
    };

    users.users.${user} = {
      group = group;
      isSystemUser = true;
    };
    users.groups.${group} = {};

    systemd.tmpfiles.rules = [
      "d ${dataDir}                            0700 ${user} ${group} - -"
      "L ${dataDir}/tls.cert                   -    -       -        - ${config.nix-bitcoin.secretsDir}/lnd-cert"
      "d ${dataDir}/data/chain/bitcoin         0700 ${user} ${group} - -"
      "L ${dataDir}/data/chain/bitcoin/mainnet -    -       -        - ${config.services.lnd.dataDir}"
    ];

    systemd.services.charge-lnd = {
      description = "Adjust LND routing fees";
      documentation = [ "https://github.com/accumulator/charge-lnd/blob/master/README.md" ];
      after = [ "lnd.service" ];
      requires = [ "lnd.service" ];
      serviceConfig = nbLib.defaultHardening // {
        ExecStart = ''${pkg}/bin/charge-lnd \
          --lnddir ${dataDir} \
          --grpc "${config.services.lnd.rpcAddress}:${toString config.services.lnd.rpcPort}" \
          --config ${pkgs.writeText "lnd-charge.config" configStr} \
          ${escapeShellArgs cfg.extraFlags}
        '';
        User = user;
        Group = group;
        StateDirectory = "charge-lnd";
      } // nbLib.allowedIPAddresses true;
    };

    systemd.timers.charge-lnd = {
      description = "Adjust LND routing fees";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.interval;
        RandomizedDelaySec = cfg.randomizedDelaySec;
      };
    };

    assertions = [
      { assertion = all (pol: pol ? "name") cfg.policies;
        message = "Attribute 'name' required for every policy.";
      }
    ];
  };
}
