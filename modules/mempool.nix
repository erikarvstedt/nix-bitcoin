{ config, lib, pkgs, ... }:

with lib;
let
  options.services.mempool = {
    enable = mkEnableOption "Mempool, a fully featured Bitcoin visualizer, explorer, and API service.";
    port = mkOption {
      type = types.port;
      default = 8999;
      description = "HTTP server port.";
    };
    user = mkOption {
      type = types.str;
      default = "mempool";
      description = "The user as which to run RTL.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run RTL.";
    };
    tor.enforce = nbLib.tor.enforce;
  };

  cfg = config.services.mempool;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;
  secretsDir = config.nix-bitcoin.secretsDir;

  configFile = builtins.toFile "mempool-config" ''
    {
      "MEMPOOL": {
	"NETWORK": "mainnet",
	"BACKEND": "electrum",
	"HTTP_PORT": ${cfg.port},
	"SPAWN_CLUSTER_PROCS": 0,
	"API_URL_PREFIX": "/api/v1/",
	"POLL_RATE_MS": 2000,
	"CACHE_DIR": "/run/mempool",
	"CLEAR_PROTECTION_MINUTES": 20 
      },
      "CORE_RPC": {
	"HOST": "${bitcoind.rpc.address}",
	"PORT": ${bitcoind.rpc.port},
	"USERNAME": "${bitcoind.rpc.users.public.name}",
	"PASSWORD": "placeholder"
      },
      "ELECTRUM": {
	"HOST": "${electrs.address}",
	"PORT": ${electrs.port},
	"TLS_ENABLED": false
      },
      "DATABASE": {
	"ENABLED": true,
	"HOST": "127.0.0.1",
	"PORT": ${config.services.mysql.port},
	"DATABASE": "mempool",
	"USERNAME": "${cfg.user}",
	"PASSWORD": "placeholder"
      },
      "STATISTICS": {
	"ENABLED": true,
	"TX_PER_SECOND_SAMPLE_PERIOD": 150
      }
    } 
  '';

  inherit (config.services)
    bitcoind
    electrs;
in {
  inherit options;

  config = mkIf cfg.enable {
    services.electrs.enable = true;
    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      initialDatabases = [{name = "mempool";}];
      initialScript = "${secretsDir}/mempool-db-initialScript";
    };

    systemd.services.mempool-backend = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "electrs.service" ];
      after = [ "electrs.service" ]; 
      serviceConfig = nbLib.defaultHardening // {
        RuntimeDirectory = "mempool";
        ExecStart = "${nbPkgs.mempool-backend}/bin/mempool-backend";
        # Show "mempool" instead of "node" in the journal
        SyslogIdentifier = "mempool";
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "10s";
      } // nbLib.allowLocalIPAddresses
        // nbLib.nodejs;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ "bitcoinrpc-public" ];
    };
    users.groups.${cfg.group} = {};

    nix-bitcoin.secrets.mempool-db-initialScript.user = config.services.mysql.user;
    nix-bitcoin.generateSecretsCmds.mempool = ''
      makePasswordSecret mempool-db-password
      if [[ mempool-db-password -nt mempool-db-initialScript ]]; then
         echo "grant all privileges on mempool.* to '${cfg.user}'@'%' identified by '$(cat mempool-db-password)'" > mempool-db-initialScript
      fi
    '';
  };
}
