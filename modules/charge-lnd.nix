{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.charge-lnd;
  nbLib = config.nix-bitcoin.lib;

  user = "charge-lnd";
  group = user;
  dataDir = "/var/lib/charge-lnd";
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
        Systemd calendar expression when to adjust fees.

        See <citerefentry><refentrytitle>systemd.time</refentrytitle>
        <manvolnum>7</manvolnum></citerefentry> for possible values.

        Default is once a day.
      '';
    };

    randomDelay = mkOption {
      type = str;
      default = "1h";
      description = ''
        Random delay to add to scheduled time.
      '';
    };

    policies = mkOption {
      type = types.lines;
      default = "";
      example = literalExample ''
        [discourage-routing-out-of-balance]
        chan.max_ratio = 0.1
        chan.min_capacity = 250000
        strategy = static
        base_fee_msat = 10000
        fee_ppm = 500

        [encourage-routing-to-balance]
        chan.min_ratio = 0.9
        chan.min_capacity = 250000
        strategy = static
        base_fee_msat = 1
        fee_ppm = 2

        [default]
        strategy = ignore
      '';
      description = ''
        Policy definitions in INI format.

        See https://github.com/accumulator/charge-lnd/blob/master/README.md#usage
        for possible properties and parameters.

        Policies are evaluated from top to bottom.
        The first matching policy (or `default`) is applied.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.lnd.macaroons.charge-lnd = {
      user = user;
      permissions = ''{"entity":"info","action":"read"},{"entity":"onchain","action":"read"},{"entity":"offchain","action":"read"},{"entity":"offchain","action":"write"}'';
    };

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
        ExecStart = ''
          ${config.nix-bitcoin.pkgs.charge-lnd}/bin/charge-lnd \
            --lnddir ${dataDir} \
            --grpc "${config.services.lnd.rpcAddress}:${toString config.services.lnd.rpcPort}" \
            --config ${builtins.toFile "lnd-charge.config" cfg.policies} \
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
        RandomizedDelaySec = cfg.randomDelay;
      };
    };

    users.users.${user} = {
      group = group;
      isSystemUser = true;
    };
    users.groups.${group} = {};
  };
}
