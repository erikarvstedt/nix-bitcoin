{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lightning-pool;
  inherit (config) nix-bitcoin-services;
  secretsDir = config.nix-bitcoin.secretsDir;
  network = config.services.bitcoind.network;
  rpclisten = "${cfg.rpcAddress}:${toString cfg.rpcPort}";
  configFile = builtins.toFile "pool.conf" ''
    rpclisten=${rpclisten}
    restlisten=${cfg.restAddress}:${toString cfg.restPort}

    lnd.host=${config.services.lnd.rpcAddress}:${toString config.services.lnd.rpcPort}
    lnd.macaroondir=${config.services.lnd.networkDir}
    lnd.tlspath=${secretsDir}/lnd-cert

    ${cfg.extraConfig}
  '';
in {
  options.services.lightning-pool = {
    enable = mkEnableOption "lightning-pool";
    rpcAddress = mkOption {
       type = types.str;
       default = "localhost";
       description = "Address to listen for gRPC connections.";
    };
    rpcPort = mkOption {
       type = types.port;
       default = 12010;
       description = "Port to listen for gRPC connections.";
    };
    restAddress = mkOption {
       type = types.str;
       default = cfg.rpcAddress;
       description = "Address to listen for REST connections.";
    };
    restPort = mkOption {
       type = types.port;
       default = 8281;
       description = "Port to listen for REST connections.";
    };
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.lightning-pool;
      description = "The package providing lightning-pool binaries.";
    };
    baseDir = mkOption {
      type = types.path;
      default = "/var/lib/lightning-pool";
      description = "The data directory for lightning-pool.";
    };
    extraConfig = mkOption {
      type = types.lines;
      default = "";
      example = ''
        debuglevel=trace
      '';
      description = "Extra lines appended to the configuration file.";
    };
    cli = mkOption {
      default = pkgs.writeScriptBin "pool" ''
        ${cfg.package}/bin/pool \
        --rpcserver ${rpclisten} \
        --network ${network} \
        --basedir ${cfg.baseDir} "$@"
      '';
      description = "Binary to connect with the lightning-pool instance.";
    };
    enforceTor = nix-bitcoin-services.enforceTor;
  };

  config = mkIf cfg.enable {
    assertions = [
      { assertion = config.services.lnd.getPublicAddressCmd != "";
        message = ''
          Pool requires a publicly reachable uri. Enable
          nix-bitcoin.onionServices.lnd.public to announce a v3 onion service.
        '';
      }
    ];

    services.lnd.enable = true;

    environment.systemPackages = [ cfg.package (hiPrio cfg.cli) ];

    systemd.tmpfiles.rules = [
      "d '${cfg.baseDir}' 0770 lnd lnd - -"
    ];

    systemd.services.lightning-pool = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "lnd.service" ];
      after = [ "lnd.service" ];
      preStart = ''
        mkdir -p ${cfg.baseDir}/${network}
        chown -R 'lnd:lnd' '${cfg.baseDir}'
        install -m 640 ${configFile} '${cfg.baseDir}/${network}/poold.conf'
      '';
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        ExecStart = "${cfg.package}/bin/poold --basedir=${cfg.baseDir} --network=${network}";
        User = "lnd";
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.baseDir;
      } // (if cfg.enforceTor
            then nix-bitcoin-services.allowTor
            else nix-bitcoin-services.allowAnyIP);
    };
  };
}
