# Define an operator user for convenient interactive access to nix-bitcoin
# features and services.
#
# When using nix-bitcoin as part of a larger system config, set
# `nix-bitcoin.operator.name` to your main user name.

{ config, lib, pkgs, options, ... }:

with lib;
let
  cfg = config.nix-bitcoin.operator;

  activeServices = let
    s = config.services;
  in builtins.filter (service:
    # Check if service exists.
    # This allows using this module within a reduced nix-bitcoin module set
    builtins.hasAttr service s && s.${service}.enable
  ) cfg.services;

in {
  options.nix-bitcoin.operator = {
    enable = mkEnableOption "operator user";
    name = mkOption {
      type = types.str;
      default = "operator";
      description = "User name.";
    };
    groups = mkOption {
      type = with types; listOf str;
      default = [];
      description = "Extra groups.";
    };
    allowRunAsUsers = mkOption {
      type = with types; listOf str;
      default = [];
      description = "Users as which the operator is allowed to run commands.";
    };
    allowServiceControl = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Allow operator to control (e.g. start, stop) the services defined in option `services`.
      '';
    };
    services = mkOption {
      type = with types; listOf str;
      default = [];
      description = "Services which the operator user is allowed to control.";
    };
  };

  config = mkIf cfg.enable {
    users.users.${cfg.name} = {
      isNormalUser = true;
      extraGroups = [
        "systemd-journal"
        "proc" # Enable full /proc access and systemd-status
      ] ++ cfg.groups;
    };

    security = {
      # Use doas instead of sudo if enabled
      doas.extraConfig = mkIf (cfg.allowRunAsUsers != [] && config.security.doas.enable) ''
        ${lib.concatMapStrings (user: "permit nopass ${cfg.name} as ${user}\n") cfg.allowRunAsUsers}
      '';
      sudo.extraConfig = mkIf (cfg.allowRunAsUsers != [] && !config.security.doas.enable) ''
        ${cfg.name} ALL=(${builtins.concatStringsSep "," cfg.allowRunAsUsers}) NOPASSWD: ALL
      '';

      # Add polkit rule to allow operator to control `activeServices`
      polkit.extraConfig = mkIf (cfg.allowServiceControl && activeServices != []) ''
        (function() {
          const operatorServices = new Set([
            ${concatMapStringsSep ", " (s: ''"${s}.service"'') activeServices}
          ]);

          polkit.addRule(function(action, subject) {
            if (action.id == "org.freedesktop.systemd1.manage-units" &&
                subject.user == "${cfg.name}" &&
                operatorServices.has(action.lookup("unit")))
            {
              return polkit.Result.YES;
            }
          });
        }())
      '';
    };

    nix-bitcoin.operator.services = [
      "bitcoind"
      "clightning"
      "lnd"
      "liquidd"
      "electrs"
      "spark-wallet"
      "recurring-donations"
      "lightning-loop"
      "nbxplorer"
      "btcpayserver"
      "joinmarket"
      "joinmarket-ob-watcher"
      # System services
      "duplicity"
      "nginx"
    ];
  };
}
