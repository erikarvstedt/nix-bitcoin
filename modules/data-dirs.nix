{ config, lib, pkgs, ... }:

with lib;
let
  options.nix-bitcoin.dataDirs = mkOption {
      default = {};
      type = with types; attrsOf (submodule {
          options = {
            user = mkOption {
              type = str;
            };
            group = mkOption {
              type = nullOr str;
              default = null;
              description = ''
                If `null`, the default group of `user` is used.
              '';
            };
            mode = mkOption {
              type = str;
              default = "770";
            };
          };
        }
      );
      description = ''
        Directories to be created when switching configurations.
        Used to setup data dirs for services.

        Directories are created right after `systemd.tmpfiles.rules` are processed.

        The directory is set to `user`, `group`, `mode`.
        If needed, its parent dirs are created with the same user, group, mode.

        If the directory already exists and is owned by a different user or group,
        ownership of its contents is recursively changed to `user`, `group`.
        This step ensures that a service with existing data dirs continues to work when
        its user/group has changed after the service has been disabled and later reenabled.
        This step cannot be efficiently implemented with `systemd-tmpfiles`.
      '';
      example = {
        "/var/lib/mydir" = {
          user = "myuser";
          mode = "750";
        };
      };
    };

  cfg = config.nix-bitcoin.dataDirs;

  configFile = builtins.toFile "setup-dirs.conf" (concatStrings (mapAttrsToList (path: attrs: ''
    ${path}:${attrs.user}:${if attrs.group == null then "" else attrs.group}:${attrs.mode}
  '') cfg));

  setupDirsApp = "${config.nix-bitcoin.pkgs.setup-dirs}/bin/setup-dirs";

  setupDirsCmd = ''system("${setupDirsApp}", "${configFile}") == 0 or $res = 3;'';
in {
  inherit options;

  config = mkIf (cfg != {}) {
    # Insert setupDirsCmd after call to systemd-tmpfiles in switch-to-configuration
    system.extraSystemBuilderCmds = ''
      if [[ $(grep -o systemd-tmpfiles $out/bin/switch-to-configuration | wc -l) != 1 ]]; then
          echo "error: string 'systemd-tmpfiles' doesn't appear exactly once in switch-to-configuration"
          exit 1
      fi
      sed -i '/systemd-tmpfiles/a ${setupDirsCmd}' $out/bin/switch-to-configuration
    '';

    systemd.services.nix-bitcoin-data-dirs = rec {
      wantedBy = [ "systemd-tmpfiles-setup.service" ];
      after = wantedBy;
      serviceConfig = {
        ExecStart = "${setupDirsApp} ${configFile}";
      };
    };
  };
}
