{ config, lib, pkgs, ... }:

with lib;
let
  options.services.minimint = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable Minimint, a federated Chaumian e-cash mint backed
        by bitcoin with deposits and withdrawals that can occur on-chain
        or via Lightning.
      '';
    };
    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen for RPC connections.";
    };
    port = mkOption {
      type = types.port;
      default = 5000;
      description = "Port to listen for RPC connections.";
    };
    extraArgs = mkOption {
      type = types.separatedString " ";
      default = "";
      description = "Extra command line arguments passed to minimint.";
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/minimint";
      description = "The data directory for minimint.";
    };
    user = mkOption {
      type = types.str;
      default = "minimint";
      description = "The user as which to run minimint.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run minimint.";
    };
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.minimint;
      defaultText = "config.nix-bitcoin.pkgs.minimint";
      description = "The package providing minimint binaries.";
    };
  };

  cfg = config.services.minimint;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;
  runAsUser = config.nix-bitcoin.runAsUserCmd;
  secretsDir = config.nix-bitcoin.secretsDir;
  bitcoind = config.services.bitcoind;

in {
  inherit options;

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    services.bitcoind = {
      enable = true;
      txindex = true;
      regtest = true;
    };
    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];
    systemd.services.minimint = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      preStart = ''
        ${config.nix-bitcoin.pkgs.minimint}/bin/configgen ${cfg.dataDir} 1 4000 5000 1 10 100 1000 10000 100000 1000000
        sed -i -e "s/127.0.0.1:18443/${nbLib.addressWithPort bitcoind.rpc.address bitcoind.rpc.port}/g" ${cfg.dataDir}/server-0.json
        sed -i -e 's/user": "bitcoin"/user": "${bitcoind.rpc.users.public.name}"/g' ${cfg.dataDir}/server-0.json
        PASS=$(cat ${secretsDir}/bitcoin-rpcpassword-public)
        sed -i -e "s/bitcoin/$PASS/g" ${cfg.dataDir}/server-0.json
      '';
      serviceConfig = nbLib.defaultHardening // {
        WorkingDirectory = cfg.dataDir;
        ExecStart = ''
          ${cfg.package}/bin/server ${cfg.dataDir}/server-0.json ${cfg.dataDir}/mint-0.db
        '';
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.dataDir;
      } // nbLib.allowLocalIPAddresses;
    };
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ "bitcoinrpc-public" ];
    };
    users.groups.${cfg.group} = {};
    nix-bitcoin.operator = {
      groups = [ cfg.group ];
      allowRunAsUsers = [ cfg.user ];
    };
  };
}
