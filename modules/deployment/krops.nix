{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.krops.secrets;
  secret-file = types.submodule ({ config, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        default = config._module.args.name;
      };
      path = mkOption {
        type = types.str;
        default = "/run/keys/${config.name}";
      };
      permissions = mkOption {
        type = types.str;
        default = "0400";
      };
      user = mkOption {
        type = types.str;
        default = "root";
      };
      group = mkOption {
        type = types.str;
        default = "root";
      };
      source-path = mkOption {
        type = types.str;
        default = toString <secrets> + "/${config.name}";
      };
    };
  });
in {
  options.krops.secrets = {
    files = mkOption {
      type = with types; attrsOf secret-file;
      default = {};
    };
  };

  config = lib.mkIf (cfg.files != {}) {
    systemd.targets.nix-bitcoin-secrets = {
      requires = [ "setup-secrets.service" ];
      after = [ "setup-secrets.service" ];
    };

    systemd.services.setup-secrets = {
      serviceConfig.Type = "oneshot";
      script = let
        files = unique (map (flip removeAttrs ["_module"])
                          (attrValues cfg.files));
        in ''
        echo setting up secrets...
        mkdir -p ${config.nix-bitcoin.secretsDir}
        chmod 0755 ${config.nix-bitcoin.secretsDir}
        chown root: ${config.nix-bitcoin.secretsDir}
        ${concatMapStringsSep "\n" (file: ''
          ${pkgs.coreutils}/bin/install \
            -D \
            --compare \
            --verbose \
            --mode=${lib.escapeShellArg file.permissions} \
            --owner=${lib.escapeShellArg file.user} \
            --group=${lib.escapeShellArg file.group} \
            ${lib.escapeShellArg file.source-path} \
            ${lib.escapeShellArg file.path} \
          || echo "failed to copy ${file.source-path} to ${file.path}"
        '') files}
      '';
    };
  };
}
