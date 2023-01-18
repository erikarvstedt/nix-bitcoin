{ config, options, pkgs, lib, ... }:

with lib;
{
  options = {
    nix-bitcoin = {
      pkgs = mkOption {
        type = types.attrs;
        default = (import ../pkgs { inherit pkgs; }).modulesPkgs;
        defaultText = "nix-bitcoin/pkgs.modulesPkgs";
      };

      lib = mkOption {
        readOnly = true;
        default = import ../pkgs/lib.nix lib pkgs config;
        defaultText = "nix-bitcoin/pkgs/lib.nix";
      };

      torClientAddressWithPort = mkOption {
        readOnly = true;
        default = with config.services.tor.client.socksListenAddress;
          "${addr}:${toString port}";
        defaultText = "(See source)";
      };

      # Torify binary that works with custom Tor SOCKS addresses
      # Related issue: https://github.com/NixOS/nixpkgs/issues/94236
      torify = mkOption {
        readOnly = true;
        default = pkgs.writers.writeBashBin "torify" ''
          ${pkgs.tor}/bin/torify \
            --address ${config.services.tor.client.socksListenAddress.addr} \
            "$@"
        '';
        defaultText = "(See source)";
      };

      # A helper for using doas instead of sudo when doas is enabled
      runAsUserCmd = mkOption {
        readOnly = true;
        default = if config.security.doas.enable
                  then "doas -u"
                  else "sudo -u";
        defaultText = "(See source)";
      };

      version = mkOption {
        readOnly = true;
        default = "0.0.85";
      };

      requiredVersion = mkOption {
        type = types.str;
        example = "1.5";
        description = mdDoc ''
          The nix-bitcoin version (in format <major>.<minor>) required by a NixOS configuration.

          This option can be set by modules that extend nix-bitcoin to ensure that a compatible
          version of nix-bitcoin is present.
.
          An error is raised during evaluation if nix-bitcoin's major version is not equal to the
          required major version or if nix-bitcoin's minor version is lower than the required
          minor version.
        '';
      };
    };
  };

  config = {
    # Check `requiredVersion`
    system = let
      version = builtins.splitVersion config.nix-bitcoin.version;
      major = builtins.elemAt version 0;
      minor = builtins.elemAt version 1;

      collectUnmetRequirements = unmet: requiredVersion: let
        v = builtins.splitVersion requiredVersion.value;
        requiredMajor = builtins.elemAt v 0;
        requiredMinor = builtins.elemAt v 1;
      in
        if major == requiredMajor && minor >= requiredMinor
        then unmet
        else unmet ++ [ requiredVersion ];
      unmetRequirements = builtins.foldl' collectUnmetRequirements [] options.nix-bitcoin.requiredVersion.definitionsWithLocations;
      checkVersions = if unmetRequirements != [] then builtins.throw errorMsg else {};

      errorMsg = ''

        You are using nix-bitcoin version ${config.nix-bitcoin.version}.
        This version is incompatible with some modules in your configuration:

        ${concatMapStringsSep "\n" (requirement: ''
          - nix-bitcoin version ${requirement.value} required in ${requirement.file}
        '') unmetRequirements}
        Try updating these modules or nix-bitcoin so that the version requirements are met.
      '';
    in
      # Force evaluation. An actual option value is never assigned
      checkVersions;
  };
}
