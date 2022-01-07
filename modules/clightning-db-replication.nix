{ config, lib, pkgs, ... }:

with lib;
let
  options.services.clightning.replication = {
    enable =  mkEnableOption "Native SQLITE3 database replication.";
    dataDir = mkOption {
      type = types.path;
      default = "/var/backup/clightning";
      description = "The data directory for clightning database replication.";
    };
    sshfsDestination = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "user@10.0.0.1:";
      description = ''
          The SSH destination for which an SSHFS should be mounted. SSH key is
          automatically generated and stored in secretsDir as
          `clightning-replication-ssh`. If this option is not specified,
          replication will simply be saved locally to replication.dataDir.
        '';
    };
    sshfsPort = mkOption {
      type = types.port;
      default = 22;
      description = ''
          Port of sshfsDestination for SSHFS mount.
        '';
    };
    encrypt = mkOption {
      type = types.bool;
      default = false;
      description = ''
          Whether to encrypt the replication with gocryptfs. Passwordfile is
          automatically generated and stored in secretsDir as
          `clightning-replication-password`.
        '';
    };
  };

  cfg = config.services.clightning.replication;
  inherit (config.services) clightning;

  network = config.services.bitcoind.makeNetworkName "bitcoin" "regtest";
  user = clightning.user;
  group = clightning.group;
in {
  inherit options;

  config = mkIf cfg.enable {

    services.clightning.extraConfig = let
      mainDB = "/${clightning.dataDir}/${network}/lightningd.sqlite3";
      replicaDB = "${cfg.dataDir}/${if cfg.encrypt then "md" else "bd"}/lightningd.sqlite3";
    in ''
      wallet=sqlite3://${mainDB}:${replicaDB}
    '';

    systemd.tmpfiles.rules =
         optional cfg.enable "d '${cfg.dataDir}' 0770 ${user} ${group} - -"
      ++ optional cfg.enable "d '${cfg.dataDir}/bd' 0770 ${user} ${group} - -"
      ++ optional cfg.encrypt "d '${cfg.dataDir}/md' 0770 ${user} ${group} - -";

    systemd.services.clightning.serviceConfig.ReadWritePaths = [ cfg.dataDir ];

    systemd.services.clightning-prepare-replication = mkIf (cfg.sshfsDestination != null || cfg.encrypt) {
      requiredBy = [ "clightning.service" ];
      before = [ "clightning.service" ];
      after = [ "setup-secrets.service" ];
      path = [
        # This includes the SUID-wrapped `fusermount` binary which enables FUSE
        # for non-root users
        "/run/wrappers"
      ] ++ optionals cfg.encrypt [
        # Includes `logger`, required by gocryptfs
        pkgs.util-linux
      ];

      script = ''
        ${optionalString (cfg.sshfsDestination != null) ''
          ${pkgs.sshfs}/bin/sshfs ${cfg.sshfsDestination} -p ${toString cfg.sshfsPort} ${cfg.dataDir}/bd \
          -o reconnect,ServerAliveInterval=15,IdentityFile=${config.nix-bitcoin.secretsDir}/clightning-replication-ssh
        ''}
        ${optionalString cfg.encrypt ''
          cryptLock='${cfg.dataDir}/bd/gocryptfs.conf'
          if [[ ! -e $cryptLock ]]; then
            ${pkgs.gocryptfs}/bin/gocryptfs \
            -init -passfile ${config.nix-bitcoin.secretsDir}/clightning-replication-password \
            ${cfg.dataDir}/bd
          fi
          ${pkgs.gocryptfs}/bin/gocryptfs \
          -passfile ${config.nix-bitcoin.secretsDir}/clightning-replication-password \
          ${cfg.dataDir}/bd ${cfg.dataDir}/md
        ''}
      '';
      serviceConfig = {
        User = user;
        RemainAfterExit = "yes";
        Type = "oneshot";
      };
    };

    nix-bitcoin.secrets.clightning-replication-password.user = user;
    nix-bitcoin.generateSecretsCmds.clightning-replication-password = ''
      makePasswordSecret clightning-replication-password
    '';
    nix-bitcoin.secrets.clightning-replication-ssh.user = user;
    nix-bitcoin.secrets.clightning-replication-ssh.permissions = "0400";
    nix-bitcoin.generateSecretsCmds.clightning-replication-ssh = ''
      ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f clightning-replication-ssh -q -N ""
    '';
  };
}
