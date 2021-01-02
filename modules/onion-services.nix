# This module creates onion-services for NixOS services.
# An onion service can be enabled for every service that defines
# options 'address', 'port' and optionally 'getAnnounceAddressCmd'.
#
# See it in use at ./presets/enable-tor.nix

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nix-bitcoin.onionServices;

  services = builtins.attrNames cfg;

  activeServices = builtins.filter (service:
    config.services.${service}.enable && cfg.${service}.enable
  ) services;

  announcingServices = builtins.filter (service: cfg.${service}.announce) activeServices;
in {
  options.nix-bitcoin.onionServices = mkOption {
    default = {};
    type = with types; attrsOf (submodule {
      options = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Create an onion service for the given service.
            The service must define options 'address' and 'port'.
          '';
        };
        announce = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Configure the service to announce its onion address.
            Only available for services that define the option `getAnnounceAddressCmd`.
          '';
        };
        externalPort = mkOption {
          type = types.nullOr types.port;
          default = null;
          description = "Override the external port of the onion service.";
        };
      };
    });
  };

  config = mkMerge [
    (mkIf (cfg != {}) {
      # Define hidden services
      services.tor = {
        enable = true;
        hiddenServices = genAttrs activeServices (name:
          let
            service = config.services.${name};
            inherit (cfg.${name}) externalPort;
          in {
            map = [{
              port = if externalPort != null then externalPort else service.port;
              toPort = service.port;
              toHost = if service.address == "0.0.0.0" then "127.0.0.1" else service.address;
            }];
            version = 3;
          }
        );
      };

      # Enable announcing services to access their own onion addresses
      nix-bitcoin.onionAddresses.access = (
        genAttrs announcingServices singleton
      ) // {
        # The operator user can access onion addresses for all active services
        operator = mkIf config.nix-bitcoin.operator.enable activeServices;
      };
      systemd.services = let
        onionAddresses = [ "onion-addresses.service" ];
      in genAttrs announcingServices (service: {
        requires = onionAddresses;
        after = onionAddresses;
      });
    })

    # Set getAnnounceAddressCmd for announcing services
    {
      services = let
        # announcingServices' doesn't depend on config.services.*.enable,
        # so we can use it to define config.services without causing infinite recursion
        announcingServices' = builtins.filter (service:
          let srv = cfg.${service};
          in srv.announce && srv.enable
        ) services;
      in genAttrs announcingServices' (service: {
        getAnnounceAddressCmd = "cat ${config.nix-bitcoin.onionAddresses.dataDir}/${service}/${service}";
      });
    }
  ];
}
