# See `man systemd.exec` and `man systemd.resource-control` for an explanation
# of the various systemd options available through this module.

lib: pkgs:

with lib;
{
  defaultHardening = {
      PrivateTmp = "true";
      ProtectSystem = "strict";
      ProtectHome = "true";
      NoNewPrivileges = "true";
      PrivateDevices = "true";
      MemoryDenyWriteExecute = "true";
      ProtectKernelTunables = "true";
      ProtectKernelModules = "true";
      ProtectControlGroups = "true";
      RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6";
      RestrictNamespaces = "true";
      LockPersonality = "true";
      IPAddressDeny = "any";
      PrivateUsers = "true";
      CapabilityBoundingSet = "";
      # @system-service whitelist and docker seccomp blacklist
      SystemCallFilter = [ "@system-service" "~add_key clone3 get_mempolicy kcmp keyctl mbind move_pages name_to_handle_at personality process_vm_readv process_vm_writev request_key set_mempolicy setns unshare userfaultfd" ];
      SystemCallArchitectures= "native";
  };

  # nodejs applications apparently rely on memory write execute
  nodejs = { MemoryDenyWriteExecute = "false"; };
  # Allow tor traffic. Allow takes precedence over Deny.
  allowTor = {
    IPAddressAllow = "127.0.0.1/32 ::1/128";
  };
  # Allow any traffic
  allowAnyIP = { IPAddressAllow = "any"; };
  allowAnyProtocol = { RestrictAddressFamilies = "~"; };

  enforceTor = mkOption {
    type = types.bool;
    default = false;
    description = ''
      "Whether to force Tor on a service by only allowing connections from and
      to 127.0.0.1;";
    '';
  };

  script = src: pkgs.writers.writeBash "script" ''
    set -eo pipefail
    ${src}
  '';
}
