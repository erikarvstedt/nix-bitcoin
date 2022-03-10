{ config, lib, ... }:

with lib;
let
  # Options shared with ../peerswap-lnd.nix
  commonOptions = import ../peerswap-common-options.nix config lib;

  options = {
    services.clightning.plugins.peerswap = commonOptions // {
      enable = mkEnableOption "peerswap (clightning plugin)";
      package = mkOption {
        type = types.package;
        default = config.nix-bitcoin.pkgs.peerswap-clightning;
        description = "The package providing peerswap binaries.";
      };
    };
  };

  cfg = config.services.clightning.plugins.peerswap;

  inherit (config.services)
    clightning
    liquidd;

  policyFile = builtins.toFile "policy.conf" (''
    accept_all_peers=${toString cfg.allowAll}
  '' + concatMapStringsSep "\n" (nodeId: "allowlisted_peers=${nodeId}") cfg.allowedNodes);
in
{
  inherit options;

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.enableLiquid -> (config.services.liquidd.enable or false);
        message = ''
          Option `services.clightning.plugins.peerswap.enableLiquid` requires liquidd to be enabled
          (set `services.liquidd.enable = true`).
        '';
      }
    ];

    services.clightning = {
      enable = true;
      extraConfig = ''
        plugin=${cfg.package}/bin/peerswap
        peerswap-db-path=${clightning.dataDir}/peerswap/swaps
        peerswap-policy-path=${policyFile}
      '' + optionalString cfg.enableLiquid ''
        peerswap-liquid-rpchost=http://${liquidd.rpc.address}
        peerswap-liquid-rpcport=${toString liquidd.rpc.port}
        peerswap-liquid-rpcuser=${liquidd.rpcuser}
        peerswap-liquid-rpcpasswordfile=${config.nix-bitcoin.secretsDir}/liquid-rpcpassword
        peerswap-liquid-network=liquidv1
        peerswap-liquid-rpcwallet=${cfg.liquidRpcWallet}
      '';
    };

    users.users.${clightning.user}.extraGroups =
      optional cfg.enableLiquid liquidd.group;
  };
}
