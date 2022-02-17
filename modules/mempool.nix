{ config, lib, pkgs, ... }:

with lib;
let
  options.services.mempool = {
    enable = mkEnableOption "Mempool, a fully featured Bitcoin visualizer, explorer, and API service.";
    # Use nginx address as services.mempool.address so onion-services.nix can pick up on it
    address = mkOption {
      type = types.str;
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
      description = "mempool-backend address.";
    };
    backendPort = mkOption {
      type = types.port;
      default = 8999;
      description = "Backend server port.";
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/mempool";
      description = "The data directory for Mempool.";
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
    tor.enforce = nbLib.tor.enforce;
  };

  cfg = config.services.mempool;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;
  secretsDir = config.nix-bitcoin.secretsDir;
  mysqlAddress = if config.nix-bitcoin.netns-isolation.enable then
    config.nix-bitcoin.netns-isolation.netns.mysql.address
  else
    "localhost";

  configFile = builtins.toFile "mempool-config" ''
    {
      "MEMPOOL": {
	"NETWORK": "mainnet",
	"BACKEND": "electrum",
	"HTTP_PORT": ${toString cfg.backendPort},
	"CACHE_DIR": "/run/mempool"
      },
      "CORE_RPC": {
	"HOST": "${bitcoind.rpc.address}",
	"PORT": ${toString bitcoind.rpc.port},
	"USERNAME": "${bitcoind.rpc.users.public.name}",
	"PASSWORD": "@btcRpcPassword@"
      },
      "ELECTRUM": {
	"HOST": "${electrs.address}",
	"PORT": ${toString electrs.port},
	"TLS_ENABLED": false
      },
      "DATABASE": {
	"ENABLED": true,
	"HOST": "${mysqlAddress}",
	"PORT": ${toString config.services.mysql.port},
	"DATABASE": "mempool",
	"USERNAME": "${cfg.user}",
	"PASSWORD": "@mempoolDbPassword@"
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
    services.bitcoind.txindex = true;
    services.mysql = {
      enable = true;
      settings.mysqld.skip_name_resolve = true;
      package = pkgs.mariadb;
      initialDatabases = [{name = "mempool";}];
      initialScript = "${secretsDir}/mempool-db-initialScript";
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
      # Create symlink to static website content
      "L+ /var/www/mempool/browser - - - - ${nbPkgs.mempool-frontend}"
    ];

    systemd.services.mempool = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "electrs.service" ];
      after = [ "electrs.service" ];
      serviceConfig = nbLib.defaultHardening // {
        ExecStartPre = [
          (nbLib.script "mempool-setup-config" ''
            <${configFile} sed \
              -e "s|@btcRpcPassword@|$(cat ${secretsDir}/bitcoin-rpcpassword-public)|" \
              -e "s|@mempoolDbPassword@|$(cat ${secretsDir}/mempool-db-password)|" \
              > '${cfg.dataDir}/config.json'
          '')
        ];
        ExecStart = "${nbPkgs.mempool-backend.workaround}/bin/mempool-backend";
        RuntimeDirectory = "mempool";
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
        worker_connections 9000;
	multi_accept on;
      '';
      appendHttpConfig = ''
	server_name_in_redirect off;

	# reset timed out connections freeing ram
	reset_timedout_connection on;
	# maximum time between packets the client can pause when sending nginx any data
	client_body_timeout 10s;
	# maximum time the client has to send the entire header to nginx
	client_header_timeout 10s;
	# timeout which a single keep-alive client connection will stay open
	# maximum time between packets nginx is allowed to pause when sending the client data
	send_timeout 10s;

	# number of requests per connection, does not affect SPDY
	keepalive_requests 100;

	gzip_min_length 1000;

	# proxy cache
	proxy_cache off;
	proxy_cache_path /var/cache/nginx keys_zone=cache:20m levels=1:2 inactive=600s max_size=500m;

	# exempt localhost from rate limit
	geo $limited_ip {
		default		1;
		127.0.0.1	0;
	}
	map $limited_ip $limited_ip_key {
		1 $binary_remote_addr;
		0 \'\';
	}

	# rate limit requests
	limit_req_zone $limited_ip_key zone=api:5m rate=200r/m;
	limit_req_zone $limited_ip_key zone=electrs:5m rate=2000r/m;
	limit_req_status 429;

	# rate limit connections
	limit_conn_zone $limited_ip_key zone=websocket:10m;
	limit_conn_status 429;

	map $http_accept_language $header_lang {
		default en-US;
		~*^en-US en-US;
		~*^en en-US;
	        ~*^ar ar;
	        ~*^ca ca;
	        ~*^cs cs;
	        ~*^de de;
	        ~*^es es;
	        ~*^fa fa;
	        ~*^fr fr;
	        ~*^ko ko;
	        ~*^it it;
	        ~*^he he;
	        ~*^ka ka;
	        ~*^hu hu;
	        ~*^mk mk;
	        ~*^nl nl;
	        ~*^ja ja;
	        ~*^nb nb;
	        ~*^pl pl;
	        ~*^pt pt;
	        ~*^ro ro;
	        ~*^ru ru;
	        ~*^sl sl;
	        ~*^fi fi;
	        ~*^sv sv;
	        ~*^th th;
	        ~*^tr tr;
	        ~*^uk uk;
	        ~*^vi vi;
	        ~*^zh zh;
	        ~*^hi hi;
	}

	map $cookie_lang $lang {
		default $header_lang;
		~*^en-US en-US;
		~*^en en-US;
	        ~*^ar ar;
	        ~*^ca ca;
	        ~*^cs cs;
	        ~*^de de;
	        ~*^es es;
	        ~*^fa fa;
	        ~*^fr fr;
	        ~*^ko ko;
	        ~*^it it;
	        ~*^he he;
	        ~*^ka ka;
	        ~*^hu hu;
	        ~*^mk mk;
	        ~*^nl nl;
	        ~*^ja ja;
	        ~*^nb nb;
	        ~*^pl pl;
	        ~*^pt pt;
	        ~*^ro ro;
	        ~*^ru ru;
	        ~*^sl sl;
	        ~*^fi fi;
	        ~*^sv sv;
	        ~*^th th;
	        ~*^tr tr;
	        ~*^uk uk;
	        ~*^vi vi;
	        ~*^zh zh;
	        ~*^hi hi;
	}
      '';
      virtualHosts."mempool" = {
        root = "/var/www/mempool/browser";
        serverName = "_";
        listen = [ { addr = cfg.address; port = cfg.port; } ];
        extraConfig = ''
          # enable browser and proxy caching
          add_header Cache-Control "public, no-transform";

          # vary cache if user changes language preference
          add_header Vary Accept-Language;
          add_header Vary Cookie;

          # fallback for all URLs i.e. /address/foo /tx/foo /block/000
          location / {
                  try_files /$lang/$uri /$lang/$uri/ $uri $uri/ /en-US/$uri @index-redirect;
                  expires 10m;
          }
          location /resources {
                  try_files /$lang/$uri /$lang/$uri/ $uri $uri/ /en-US/$uri @index-redirect;
                  expires 1h;
          }
          location @index-redirect {
                  rewrite (.*) /$lang/index.html;
          }

          # location block using regex are matched in order

          # used to rewrite resources from /<lang>/ to /en-US/
          location ~ ^/(ar|bg|bs|ca|cs|da|de|et|el|es|eo|eu|fa|fr|gl|ko|hr|id|it|he|ka|lv|lt|hu|mk|ms|nl|ja|nb|nn|pl|pt|pt-BR|ro|ru|sk|sl|sr|sh|fi|sv|th|tr|uk|vi|zh|hi)/resources/ {
                  rewrite ^/[a-zA-Z-]*/resources/(.*) /en-US/resources/$1;
          }
          # used for cookie override
          location ~ ^/(ar|bg|bs|ca|cs|da|de|et|el|es|eo|eu|fa|fr|gl|ko|hr|id|it|he|ka|lv|lt|hu|mk|ms|nl|ja|nb|nn|pl|pt|pt-BR|ro|ru|sk|sl|sr|sh|fi|sv|th|tr|uk|vi|zh|hi)/ {
                  try_files $uri $uri/ /$1/index.html =404;
          }

          # static API docs
          location = /api {
                  try_files $uri $uri/ /en-US/index.html =404;
          }
          location = /api/ {
                  try_files $uri $uri/ /en-US/index.html =404;
          }

          # mainnet API
          location /api/v1/donations {
                  proxy_pass https://mempool.space;
          }
          location /api/v1/donations/images {
                  proxy_pass https://mempool.space;
          }
          location /api/v1/contributors {
                  proxy_pass https://mempool.space;
          }
          location /api/v1/contributors/images {
                  proxy_pass https://mempool.space;
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

          # mainnet API
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

    nix-bitcoin.secrets.mempool-db-initialScript.user = config.services.mysql.user;
    nix-bitcoin.secrets.mempool-db-password.user = cfg.user;
    nix-bitcoin.generateSecretsCmds.mempool = ''
      makePasswordSecret mempool-db-password
      if [[ mempool-db-password -nt mempool-db-initialScript ]]; then
         echo "grant all on mempool.* to '${cfg.user}'@'${cfg.backendAddress}' identified by '$(cat mempool-db-password)'" > mempool-db-initialScript
      fi
    '';
  };
}
