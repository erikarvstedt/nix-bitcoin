{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.joinmarket-ob-watcher;
  inherit (config) nix-bitcoin-services;
  nbPkgs = config.nix-bitcoin.pkgs;
  torAddress = builtins.head (builtins.split ":" config.services.tor.client.socksListenAddress);
  configFile = builtins.toFile "config" ''
    [BLOCKCHAIN]
    blockchain_source = no-blockchain

    [MESSAGING:server1]
    host = darksci3bfoka7tw.onion
    channel = joinmarket-pit
    port = 6697
    usessl = true
    socks5 = true
    socks5_host = ${torAddress}
    socks5_port = 9050

    [MESSAGING:server2]
    host = ncwkrwxpq2ikcngxq3dy2xctuheniggtqeibvgofixpzvrwpa77tozqd.onion
    channel = joinmarket-pit
    port = 6667
    usessl = false
    socks5 = true
    socks5_host = ${torAddress}
    socks5_port = 9050
  '';
in {
  options.services.joinmarket-ob-watcher = {
    enable = mkEnableOption "JoinMarket orderbook watcher";
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/joinmarket-ob-watcher";
      description = "The data directory for JoinMarket orderbook watcher.";
    };
    user = mkOption {
      type = types.str;
      default = "joinmarket-ob-watcher";
      description = "The user as which to run JoinMarket orderbook watcher.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run JoinMarket orderbook watcher.";
    };
    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        "http server listen address.";
      '';
    };
    enforceTor =  nix-bitcoin-services.enforceTor;
  };

  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
        description = "joinmarket orderbook watcher User";
        group = "${cfg.group}";
        home = cfg.dataDir;
        extraGroups = [ "tor" ];
    };
    users.groups.${cfg.group} = {};

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    services.tor = {
      enable = true;
      client.enable = true;
      controlSocket.enable = true;
    };

    systemd.services.joinmarket-ob-watcher = {
      description = "Webpage to monitor your local orderbook";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      preStart = ''
        install -o '${cfg.user}' -g '${cfg.group}' -m 640 ${configFile} ${cfg.dataDir}/joinmarket.cfg
      '';
      serviceConfig = nix-bitcoin-services.defaultHardening // rec {
        WorkingDirectory = "${cfg.dataDir}";
        ExecStart = "${nbPkgs.joinmarket}/bin/ob-watcher --datadir=${cfg.dataDir} --host=${cfg.host}";
        User = "${cfg.user}";
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = "${cfg.dataDir}";
      } // nix-bitcoin-services.allowTor;
    };
  };
}
