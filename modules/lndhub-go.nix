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
        default = 8082;
        description = "Port to listen on.";
      };
      settings = mkOption {
        type = with types; attrsOf (oneOf [ str int bool ]);
        example = {
          ALLOW_ACCOUNT_CREATION = false;
          FEE_RESERVE = true;
          MAX_SEND_AMOUNT = 1000000;
        };
        description = ''
          LndHub.go settings.
          See here for possible options:
          https://github.com/getAlby/lndhub.go#available-configuration
        '';
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
        default = cfg.user;
        description = "The group as which to run LndHub.go.";
      };
      tor.enforce = nbLib.tor.enforce;
    };
  };

  cfg = config.services.lndhub-go;
  nbLib = config.nix-bitcoin.lib;

  inherit (config.services)
    lnd
    postgresql;

  configFile = builtins.toFile "lndhub-go-conf" (lib.generators.toKeyValue {} cfg.settings);
in {
  inherit options;

  config = mkIf cfg.enable {
    services.lnd = {
      enable = true;
      macaroons.lndhub-go = {
        inherit (cfg) user;
        permissions = ''{"entity":"info","action":"read"},{"entity":"invoices","action":"read"},{"entity":"invoices","action":"write"},{"entity":"offchain","action":"read"},{"entity":"offchain","action":"write"}'';
      };
    };
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "lndhubgo" ];
      ensureUsers = [
        {
          name = cfg.user;
          ensurePermissions."DATABASE lndhubgo" = "ALL PRIVILEGES";
        }
      ];
    };

    services.lndhub-go.settings = {
      HOST = cfg.address;
      PORT = cfg.port;
      DATABASE_URI = "postgresql://${cfg.user}:@localhost:${toString postgresql.port}/lndhubgo?sslmode=disable";
      LND_ADDRESS = "${nbLib.addressWithPort lnd.address lnd.port}";
      BRANDING_TITLE = "LndHub.go - Nix-Bitcoin";
      BRANDING_DESC = "Accounting wrapper for the Lightning Network";
      BRANDING_URL = "https://nixbitcoin.org";
      BRANDING_LOGO = "https://nixbitcoin.org/files/nix-bitcoin-logo-text.png";
      BRANDING_FAVICON = "https://nixbitcoin.org/files/nix-bitcoin-logo.png";
      BRANDING_FOOTER = "about=https://nixbitcoin.org,github=https://github.com/fort-nix/nix-bitcoin";
    };

    systemd.services.lndhub-go = rec {
      wantedBy = [ "multi-user.target" ];
      requires = [ "lnd.service" "postgresql.service" ];
      after = requires;
      preStart = ''
        {
          cat ${configFile}
          echo "JWT_SECRET=$(cat ${config.nix-bitcoin.secretsDir}/lndhub.go-jwt_secret)"
          echo "LND_MACAROON_HEX=$(xxd -p -c 99999 /run/lnd/lndhub-go.macaroon)"
          echo "LND_CERT_HEX=$(xxd -p -c 99999 ${lnd.certPath})"
        } > .env
      '';
      serviceConfig = nbLib.defaultHardening // {
        StateDirectory = "lndhub-go";
        StateDirectoryMode = "770";
        WorkingDirectory = "/var/lib/lndhub-go";
        ExecStart = "${config.nix-bitcoin.pkgs.lndhub-go}/bin/lndhub.go";
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "10s";
      } // nbLib.allowedIPAddresses cfg.tor.enforce;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
    };
    users.groups.${cfg.group} = {};
    nix-bitcoin.generateSecretsCmds.lndhub-go = ''
      makePasswordSecret lndhub.go-jwt_secret
    '';
  };
}
