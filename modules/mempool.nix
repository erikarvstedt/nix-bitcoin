{ config, lib, pkgs, ... }:

with lib;
let
  options.services.mempool = {
    enable = mkEnableOption "Mempool, a fully featured Bitcoin visualizer, explorer, and API service.";
    address = mkOption {
      type = types.str;
      # nginx is used as the HTTP server
      default = if config.nix-bitcoin.netns-isolation.enable then
        config.nix-bitcoin.netns-isolation.netns.nginx.address
      else
        "localhost";
      description = "HTTP server address.";
    };
    port = mkOption {
      type = types.port;
      default = 12125; # random port for nginx
      description = "HTTP server port.";
    };
    backendAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Backend address.";
    };
    backendPort = mkOption {
      type = types.port;
      default = 8999;
      description = "Backend server port.";
    };
    electrumServer = mkOption {
      type = types.enum [ "electrs" "fulcrum" ];
      default = "electrs";
      description = "Electrum server implementation.";
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/mempool";
      description = "The data directory for Mempool.";
    };
    settings = mkOption {
      type = with types; attrsOf (attrsOf anything);
      example = {
        MEMPOOL = {
          POLL_RATE_MS = 3000;
          STDOUT_LOG_MIN_PRIORITY = "debug";
        };
        PRICE_DATA_SERVER = {
          CLEARNET_URL = "https://myserver.org/prices";
        };
      };
      description = ''
        Mempool backend settings.
        See here for possible options:
        https://github.com/mempool/mempool/blob/master/backend/src/config.ts
      '';
    };
    database = {
      name = mkOption {
        type = types.str;
        default = "mempool";
        description = "Database name.";
      };
    };
    user = mkOption {
      type = types.str;
      default = "mempool";
      description = "The user as which to run Mempool.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run Mempool.";
    };
    tor = nbLib.tor;
  };

  cfg = config.services.mempool;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;
  secretsDir = config.nix-bitcoin.secretsDir;

  configFile = builtins.toFile "mempool-config" (builtins.toJSON cfg.settings);

  inherit (config.services)
    bitcoind
    electrs
    fulcrum;

  torSocket = config.services.tor.client.socksListenAddress;
in {
  inherit options;

  config = mkIf cfg.enable {
    services.bitcoind.txindex = true;
    services.electrs.enable = mkIf (cfg.electrumServer == "electrs" ) true;
    services.fulcrum.enable = mkIf (cfg.electrumServer == "fulcrum" ) true;
    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        {
          name = cfg.user;
          ensurePermissions = { "${cfg.database.name}.*" = "ALL PRIVILEGES"; };
        }
      ];
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
      # Create symlink to static website content
      "L+ /var/www/mempool/browser - - - - ${nbPkgs.mempool-frontend}"
    ];

    # Available options:
    # https://github.com/mempool/mempool/blob/master/backend/src/config.ts
    services.mempool.settings = {
      MEMPOOL = {
        # mempool doesn't support regtest
        NETWORK = "mainnet";
        BACKEND = "electrum";
        HTTP_PORT = cfg.backendPort;
        CACHE_DIR = "/var/cache/mempool";
        STDOUT_LOG_MIN_PRIORITY = mkDefault "info";
      };
      CORE_RPC = {
        HOST = bitcoind.rpc.address;
        PORT = bitcoind.rpc.port;
        USERNAME = bitcoind.rpc.users.public.name;
        PASSWORD = "@btcRpcPassword@";
      };
      ELECTRUM = let
        server = config.services.${cfg.electrumServer};
      in {
        HOST = server.address;
        PORT = server.port;
        TLS_ENABLED = false;
      };
      DATABASE = {
        ENABLED = true;
        DATABASE = cfg.database.name;
        SOCKET = "/run/mysqld/mysqld.sock";
      };
    } // optionalAttrs (cfg.tor.proxy) {
      # Use Tor for rate fetching
      SOCKS5PROXY = {
        ENABLED = true;
        USE_ONION = true;
        HOST = torSocket.addr;
        PORT = torSocket.port;
      };
    };

    systemd.services.mempool = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "${cfg.electrumServer}.service" ];
      after = [ "${cfg.electrumServer}.service" "mysql.service" ];
      preStart = ''
        <${configFile} sed \
          -e "s|@btcRpcPassword@|$(cat ${secretsDir}/bitcoin-rpcpassword-public)|" \
          > '${cfg.dataDir}/config.json'
      '';
      environment.MEMPOOL_CONFIG_FILE = "${cfg.dataDir}/config.json";
      serviceConfig = nbLib.defaultHardening // {
        ExecStart = "${nbPkgs.mempool-backend}/bin/mempool-backend";
        CacheDirectory = "mempool";
        CacheDirectoryMode = "750";
        # Show "mempool" instead of "node" in the journal
        SyslogIdentifier = "mempool";
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.dataDir;
      } // nbLib.allowedIPAddresses cfg.tor.enforce
        // nbLib.nodejs;
    };

    services.nginx = {
      enable = true;
      enableReload = true;
      recommendedProxySettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedTlsSettings = true;
      eventsConfig = ''
        multi_accept on;
      '';
      commonHttpConfig = ''
        include ${./mempool/http-language.conf};
      '';
      virtualHosts."mempool" = {
        root = "/var/www/mempool/browser";
        serverName = "_";
        listen = [ { addr = cfg.address; port = cfg.port; } ];
        extraConfig = ''
          add_header Cache-Control "public, no-transform";

          add_header Vary Accept-Language;
          add_header Vary Cookie;

          include ${./mempool/location-static.conf};

          location = /api {
                  try_files $uri $uri/ /en-US/index.html =404;
          }
          location = /api/ {
                  try_files $uri $uri/ /en-US/index.html =404;
          }

          location /api/v1/ws {
                  proxy_pass http://${cfg.backendAddress}:${toString cfg.backendPort}/;
                  proxy_http_version 1.1;
                  proxy_set_header Upgrade $http_upgrade;
                  proxy_set_header Connection "Upgrade";
          }
          location /api/v1 {
                  proxy_pass http://${cfg.backendAddress}:${toString cfg.backendPort}/api/v1;
          }
          location /api/ {
                  proxy_pass http://${cfg.backendAddress}:${toString cfg.backendPort}/api/v1/;
          }

          location /ws {
                  proxy_pass http://${cfg.backendAddress}:${toString cfg.backendPort}/;
                  proxy_http_version 1.1;
                  proxy_set_header Upgrade $http_upgrade;
                  proxy_set_header Connection "Upgrade";
          }
        '';
      };
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ "bitcoinrpc-public" ];
    };
    users.groups.${cfg.group} = {};
  };
}
