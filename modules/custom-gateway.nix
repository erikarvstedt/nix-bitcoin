{ config, pkgs, lib, ... }:

with lib;
let
  options = {
    nix-bitcoin.customGateway = {
      services = mkOption {
        type = with types; listOf str;
        default = [];
        example = [ "bitcoind" "electrs" ];
        description = ''
          A list of nix-bitcoin services that are configured to use:
          - `interface` as the default network gateway
          - `dnsServer` as the DNS server.

          This is useful for routing WAN traffic for selected services through a VPN.

          IPv6 WAN support is disabled for these services.
          (This keeps this module simple and easily testable. IPv6 support
          can be added in the future.)
        '';
      };
      interface = mkOption {
        type = types.str;
        example = "wg0";
        description = ''
          The interface to use as the default gateway for `services`.
        '';
      };
      interfaceUnit = mkOption {
        type = types.str;
        example = "wireguard-wg0.service";
        description = ''
          The systemd unit that sets up the gateway interface.
        '';
      };
      dnsServer = mkOption {
        type = types.str;
        example = "10.0.0.1";
        description = ''
          IPv4 address of the DNS server to use for `services`.
        '';
      };
    };
  };

  # Implementation notes:
  # This module can easily be extended to work with network namespaces (netns-isolation).
  # The difference to the current implementation would be:
  # - Use a routing rule based on the packet source address instead of the UID.
  #   This ensures that the whole network namespace is matched, not only a specific user.
  # - The gai.conf tweak is not needed because missing IPv6 connectivity
  #   is auto-detected by glibc in a netns.

  cfg = config.nix-bitcoin.customGateway;

  services = builtins.filter (s: config.services.${s}.enable) cfg.services;

  forEachService = fn: concatStrings (map fn services);

  setupScriptPath = with pkgs; [
    coreutils
    iproute2
  ];

  # Setup custom routing tables for `services`
  setupScript = pkgs.writers.writeBash "setup" ''
    set -euo pipefail

    if (($# > 0)); then
      start=
    else
      start=1
    fi

    ip46() {
      ip "$@"
      ip -6 "$@"
    }

    # A random int < 2^31
    table=1593615257

    if [[ $start ]]; then
      # Set Reverse Path filtering to `loose`, otherwise packages are dropped
      # due to asymmetric routing. `loose` is already the default on NixOS,
      # but it is set to `strict` (== 1) in the `hardened` profile.
      echo 2 > /proc/sys/net/ipv4/conf/${cfg.interface}/rp_filter

      # Add a custom IPv4 routing table with `interface` as the default gateway
      ip route add table $table default dev ${cfg.interface}

      # Add a custom IPv6 routing table where the default gateway is disabled.
      ip -6 route add table $table prohibit default

      action=add
    else
      action=del
    fi

    # Enable/disable the custom routing table for each service's UID
    ${forEachService (service: ''
      uid=$(id -u ${config.services.${service}.user})
      ip46 rule $action uidrange $uid-$uid table $table
    '')}

    if [[ ! $start ]]; then
      ip46 route flush table $table
    fi
  '';

  serviceSettings = rec {
    requires = [ "custom-gateway.service "];
    after = requires;
    bindsTo = requires;

    serviceConfig = {
      # Prevent glibc from using nscd for resolving DNS requests.
      # nscd leaks the external address of the default gateway on DNS lookups.
      InaccessiblePaths = [ "-/run/nscd" ];
      BindReadOnlyPaths = [ "${resolvConf}:/etc/resolv.conf" ];
    };
  };

  resolvConf = builtins.toFile "resolv.conf" ''
    nameserver ${cfg.dnsServer}
  '';
in {
  inherit options;

  config = mkIf (services != []) {
    assertions = [
      { assertion = !(config.nix-bitcoin.netns-isolation.enable or false);
        message = "custom-gateway: netns-isolation is not (yet) supported.";
      }
    ];

    systemd.services = {
      custom-gateway = {
        requires = [ cfg.interfaceUnit ];
        after = [ cfg.interfaceUnit ];
        path = setupScriptPath;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${setupScript}";
          ExecStop = "${setupScript} stop";
        };
      };
    } // (genAttrs services (_: serviceSettings));

    # Disable reverse path filtering (RPF) for packets originating from `interface`.
    # Without this, WAN packages coming from `interface` would be dropped because
    # response packets would be routed back through another interface in the
    # default routing table.
    #
    # If RPF is disabled, chain `nixos-fw-rpfilter` doesn't exist.
    # Running `iptables -w -t raw --list nixos-fw-rpfilter` to check for existence
    # causes an unexplained 25 sec delay on firewall reloading, so simply ignore
    # errors on insertion instead.
    #
    # Add the rule at index 2 for performance:
    # `nixos-fw-rpfilter` is called for all packets, and the rule at index 1
    # early-exits on packets that pass RPF, which is the common case.
    networking.firewall.extraCommands = ''
      iptables -w -t raw -I nixos-fw-rpfilter 2 -i ${cfg.interface} -j RETURN 2>/dev/null || true
    '';
  };
}
