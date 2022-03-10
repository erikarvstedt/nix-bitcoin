{ config, lib, pkgs, ... }:

with lib;
let
  options = {
    services.peerswap-lnd = {
      enable = mkEnableOption "peerswap lnd";
      address = mkOption {
        type = types.str;
        default = "localhost";
        description = "Address to listen for gRPC connections.";
      };
      port = mkOption {
        type = types.port;
        default = 42069;
        description = "Port to listen for gRPC connections.";
      };
      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/peerswap-lnd";
        description = "The data directory for peerswap.";
      };
      allowedNodes = mkOption {
        type = types.listOf types.str;
        default = [];
        example = [ "0266e4598d1d3c415f572a8488830b60f7e744ed9235eb0b1ba93283b315c03518" ];
        description = ''
          IDs of nodes that are authorized to send a peerswap request to your node.
        '';
      };
      allowAll = mkOption {
        type = types.bool;
        default = false;
        description = "UNSAFE: Allow all nodes to swap with your node.";
      };
      enableBitcoin = mkOption {
        type = types.bool;
        default = true;
        description = "Enable bitcoin swaps.";
      };
      enableLiquid = mkOption {
        type = types.bool;
        default = config.services.liquidd.enable;
        description = "Enable liquid-btc swaps.";
      };
      liquidRpcWallet = mkOption {
        type = types.str;
        default = "peerswap";
        description = "The liquid rpc wallet to use peerswap with";
      };
      package = mkOption {
        type = types.package;
        default = config.nix-bitcoin.pkgs.peerswap-lnd;
        description = "The package providing peerswap binaries.";
      };
      user = mkOption {
        type = types.str;
        default = "peerswap";
        description = "The user as which to run peerswap.";
      };
      group = mkOption {
        type = types.str;
        default = cfg.user;
        description = "The group as which to run peerswap.";
      };
      cli = mkOption {
        default = pkgs.writeScriptBin "pscli" ''
          ${cfg.package}/bin/pscli --rpchost=${nbLib.addressWithPort cfg.address cfg.port} "$@"
        '';
        defaultText = "(See source)";
        description = "Binary to connect with the peerswap instance.";
      };
    };
  };

  cfg = config.services.peerswap-lnd;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;

  inherit (config.services)
    liquidd
    lnd;

  configFile = builtins.toFile "peerswap.conf" (''
    host=${nbLib.addressWithPort cfg.address cfg.port}
    datadir=${cfg.dataDir}
    lnd.macaroonpath=${cfg.dataDir}/peerswap.macaroon
    lnd.tlscertpath=${lnd.certPath}
    lnd.host=${nbLib.addressWithPort lnd.rpcAddress lnd.rpcPort}
    bitcoinswaps=${toString cfg.enableBitcoin}
    accept_all_peers=${toString cfg.allowAll}
  '' + optionalString cfg.enableLiquid ''
    liquid.rpchost=http://${liquidd.rpc.address}
    liquid.rpcport=${toString liquidd.rpc.port}
    liquid.rpcuser=${liquidd.rpcuser}
    liquid.rpcpasswordfile=${config.nix-bitcoin.secretsDir}/liquid-rpcpassword
    liquid.network=liquidv1
    liquid.rpcwallet=${cfg.liquidRpcWallet}
  '' +
    concatMapStringsSep "\n" (nodeId: "allowlisted_peers=${nodeId}") cfg.allowedNodes
  );
in
{
  inherit options;

  config = mkIf cfg.enable {
    services.lnd = {
      enable = true;
      macaroons.peerswap = {
        user = cfg.user;
        permissions = ''{"entity":"info","action":"read"},{"entity":"onchain","action":"write"},{"entity":"onchain","action":"read"},{"entity":"invoices","action":"write"},{"entity":"invoices","action":"read"},{"entity":"offchain","action":"write"},{"entity":"offchain","action":"read"},{"entity":"peers","action":"read"}'';
      };
    };

    environment.systemPackages = [ cfg.package (hiPrio cfg.cli) ];

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${lnd.user} ${lnd.group} - -"
    ];

    systemd.services.peerswap-lnd = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "lnd.service" ];
      after = [ "lnd.service" ];
      preStart = ''
        ln -sf /run/lnd/peerswap.macaroon ${cfg.dataDir}
      '';
      serviceConfig = nbLib.defaultHardening // {
        ExecStart = "${cfg.package}/bin/peerswapd --configfile=${configFile}";
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = cfg.dataDir;
      } // nbLib.allowLocalIPAddresses;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      extraGroups = [
        lnd.group
      ] ++ optional cfg.enableLiquid liquidd.group;
    };
    users.groups.${cfg.group} = {};
  };
}
