{ config, lib, pkgs, ... }:

with lib;
let
  options.services = {
    lndhub-go = {
      enable = mkEnableOption "LndHub.go, an accounting wrapper for the Lightning Network";
      address = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Address to listen on.";
      };
      port = mkOption {
        type = types.port;
        default = 3001;
        description = "Port to listen on.";
      };
      feeReserve = mkOption {
        type = types.bool;
        default = false;
        description = "Keep fee reserve for each user.";
      };
      allowAccountCreation = mkOption {
        type = types.bool;
        default = true;
        description = "Enable creation of new accounts.";
      };
      maxReceiveAmount = mkOption {
        type = types.ints.unsigned;
        default = 0;  # 0 = no limit
        description = "Set maximum amount (in satoshi) for which an invoice can be created.";
      };
      maxSendAmount = mkOption {
        type = types.ints.unsigned;
        default = 0;  # 0 = no limit
        description = "Set maximum amount (in satoshi) of an invoice that can be paid.";
      };
      maxAccountBalance = mkOption {
        type = types.ints.unsigned;
        default = 0;  # 0 = no limit
        description = "Set maximum balance (in satoshi) for each account.";
      };
      package = mkOption {
        type = types.package;
        default = config.nix-bitcoin.pkgs.lndhub-go;
        defaultText = "config.nix-bitcoin.pkgs.lndhub-go";
        description = "The package providing LndHub.go binaries.";
      };
      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/lndhub-go";
        description = "The data directory for LndHub.go.";
      };
      user = mkOption {
        type = types.str;
        default = "lndhub-go";
        description = "The user as which to run LndHub.go.";
      };
      group = mkOption {
        type = types.str;
        default = cfg.lndhub-go.user;
        description = "The group as which to run LndHub.go.";
      };
      tor.enforce = nbLib.tor.enforce;
    };
  };

  cfg = config.services;
  nbLib = config.nix-bitcoin.lib;

in {
  inherit options;

  config = mkIf cfg.lndhub-go.enable {
    services.lnd = {
      enable = true;
      macaroons.lndhub-go = {
        inherit (cfg.lndhub-go) user;
        permissions = ''{"entity":"info","action":"read"},{"entity":"invoices","action":"read"},{"entity":"invoices","action":"write"},{"entity":"offchain","action":"read"},{"entity":"offchain","action":"write"}'';
      };
    };
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "lndhub-go" ];
      ensureUsers = [
        {
          name = cfg.lndhub-go.user;
          ensurePermissions."DATABASE lndhub-go" = "ALL PRIVILEGES";
        }
      ];
    };

    systemd.services.lndhub-go = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "lnd.service" "postgresql.service" ];
      after = [ "lnd.service" "postgresql.service" ];
      preStart = ''
        mkdir -p '${cfg.lndhub-go.dataDir}'
        {
          echo "DATABASE_URI=postgresql://${cfg.lndhub-go.user}:@localhost:${toString cfg.postgresql.port}/lndhub-go?sslmode=disable"
          echo "JWT_SECRET=$(cat ${config.nix-bitcoin.secretsDir}/lndhub.go-jwt_secret)"
          echo "LND_ADDRESS=${cfg.lnd.address}:${toString cfg.lnd.port}"
          echo "LND_MACAROON_HEX=$(xxd -p -c 99999 /run/lnd/lndhub-go.macaroon)"
          echo "LND_CERT_HEX=$(xxd -p -c 99999 ${cfg.lnd.certPath})"
          echo "HOST=${cfg.lndhub-go.address}"
          echo "PORT=${toString cfg.lndhub-go.port}"
          echo "FEE_RESERVE=${toString cfg.lndhub-go.feeReserve}"
          echo "ALLOW_ACCOUNT_CREATION=${toString cfg.lndhub-go.allowAccountCreation}"
          echo "MAX_RECEIVE_AMOUNT=${toString cfg.lndhub-go.maxReceiveAmount}"
          echo "MAX_SEND_AMOUNT=${toString cfg.lndhub-go.maxSendAmount}"
          echo "MAX_ACCOUNT_BALANCE=${toString cfg.lndhub-go.maxAccountBalance}"
          echo "BRANDING_TITLE=LndHub.go - Nix-Bitcoin"
          echo "BRANDING_DESC=Accounting wrapper for the Lightning Network"
          echo "BRANDING_URL=https://nixbitcoin.org"
          echo "BRANDING_LOGO=https://nixbitcoin.org/files/nix-bitcoin-logo-text.png"
          echo "BRANDING_FAVICON=https://nixbitcoin.org/files/nix-bitcoin-logo.png"
          echo "BRANDING_FOOTER=about=https://nixbitcoin.org,github=https://github.com/fort-nix/nix-bitcoin"
        } > '${cfg.lndhub-go.dataDir}/lndhub-go.env'
        chmod 600 '${cfg.lndhub-go.dataDir}/lndhub-go.env'
      '';
      serviceConfig = nbLib.defaultHardening // {
        EnvironmentFile = "${cfg.lndhub-go.dataDir}/lndhub-go.env";
        ExecStart = ''
          ${cfg.lndhub-go.package}/bin/lndhub.go
        '';
        User = cfg.lndhub-go.user;
        Restart = "on-failure";
        RestartSec = "10s";
      } // nbLib.allowedIPAddresses cfg.lndhub-go.tor.enforce;
    };

    users.users.${cfg.lndhub-go.user} = {
      isSystemUser = true;
      group = cfg.lndhub-go.group;
    };
    users.groups.${cfg.lndhub-go.group} = {};
    nix-bitcoin.generateSecretsCmds.lndhub-go = ''
      makePasswordSecret lndhub.go-jwt_secret
    '';
  };
}
