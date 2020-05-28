{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nix-bitcoin.netns-isolation;

  mkHiddenService = map: {
    map = [ map ];
    version = 3;
  };

  netns = builtins.mapAttrs (n: v: {
    inherit (v) id;
    address = "169.254.0.${toString v.id}";
    availableNetns = builtins.filter (x: config.services.${x}.enable) availableNetns.${n};
  }) enabledServices;

  # Symmetric netns connection matrix
  # if clightning.connections = [ "bitcoind" ]; then
  #   availableNetns.bitcoind = [ "clighting" ];
  #   and
  #   availableNetns.clighting = [ "bitcoind" ];
  availableNetns = let
    # base = { clightning = [ "bitcoind" ]; ... }
    base = builtins.mapAttrs (n: v:
      builtins.filter isEnabled v.connections
    ) enabledServices;
  in
    foldl (xs: s1:
      foldl (xs: s2:
        xs // { "${s2}" = xs.${s2} ++ [ s1 ]; }
      ) xs cfg.services.${s1}.connections
    ) base (builtins.attrNames base);

  enabledServices = filterAttrs (n: v: isEnabled n) cfg.services;
  isEnabled = x: config.services.${x}.enable;

  ip = "${pkgs.iproute}/bin/ip";
  iptables = "${pkgs.iptables}/bin/iptables";

in {
  options.nix-bitcoin.netns-isolation = {
    enable = mkEnableOption "netns isolation";

    services = mkOption {
      default = {};
      type = types.attrsOf (types.submodule {
        options = {
          id = mkOption { type = types.int; };
          connections = mkOption {
            type = with types; listOf str;
            default = [];
          };
        };
      });
    };
  };

  config = mkIf cfg.enable {
    # Prerequisites
    networking.dhcpcd.extraConfig = "noipv4ll";
    services.tor.client.socksListenAddress = "169.254.0.10:9050";
    networking.firewall.interfaces.br0.allowedTCPPorts = [ 9050 ];
    boot.kernel.sysctl."net.ipv4.ip_forward" = true;

    nix-bitcoin.netns-isolation.services = {
      bitcoind = {
        id = 12;
      };
      electrs = {
        id = 16;
        connections = [ "bitcoind" ];
      };
    };

    systemd.services = {
      netns-bridge = {
        description = "Create bridge";
        requiredBy = [ "tor.service" ];
        before = [ "tor.service" ];
        script = ''
          ${ip} link add name br0 type bridge
          ${ip} link set br0 up
          ${ip} addr add 169.254.0.10/24 brd + dev br0
          ${iptables} -t nat -A POSTROUTING -s 169.254.0.0/24 -j MASQUERADE
        '';
        preStop = ''
          ${iptables} -t nat -D POSTROUTING -s 169.254.0.0/24 -j MASQUERADE
          ${ip} link del br0
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = "yes";
        };
      };
    } //
    (let
      makeNetnsServices = n: v: let
        vethName = "nb-veth-${toString v.id}";
        netnsName = "nb-${n}";
        ipNetns = "${ip} -n ${netnsName}";
        netnsIptables = "${ip} netns exec ${netnsName} ${pkgs.iptables}/bin/iptables";
      in {
        "${n}".serviceConfig.NetworkNamespacePath = "/var/run/netns/${netnsName}";

        "netns-${n}" = rec {
          requires = [ "netns-bridge.service" ];
          after = [ "netns-bridge.service" ];
          bindsTo = [ "${n}.service" ];
          requiredBy = bindsTo;
          before = bindsTo;
          script = ''
            ${ip} netns add ${netnsName}
            ${ipNetns}link set lo up
            ${ip} link add ${vethName} type veth peer name br-${vethName}
            ${ip} link set ${vethName} netns ${netnsName}
            ${ipNetns} addr add ${v.address}/24 dev ${vethName}
            ${ip} link set br-${vethName} up
            ${ipNetns} link set ${vethName} up
            ${ip} link set br-${vethName} master br0
            ${ipNetns} route add default via 169.254.0.10
            ${netnsIptables} -P INPUT DROP"
            ${netnsIptables} -A INPUT -s 127.0.0.1,169.254.0.10 -j ACCEPT
          '' + (optionalString config.services.${n}.enforceTor) ''
            ${netnsIptables} -P OUTPUT DROP"
            ${netnsIptables} -A OUTPUT -d 127.0.0.1,169.254.0.10 -j ACCEPT"
          '' + concatMapStrings (otherNetns: let
            other = netns.${otherNetns};
          in ''
            ${netnsIptables} -A INPUT -s ${other.address} -j ACCEPT"
            ${netnsIptables} -A OUTPUT -d ${other.address} -j ACCEPT"
          '') v.availableNetns;
          preStop = ''
            ${ip} netns delete ${netnsName}
            ${ip} link del br-${vethName}
          '';
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = "yes";
            ExecStartPre = "-${ip} netns delete ${netnsName}";
          };
        };
      };
    in foldl (services: n:
      services // (makeNetnsServices n netns.${n})
    ) {} (builtins.attrNames netns));

    # bitcoin: Custom netns configs
    # TODO: Override hiddenServices
    # TODO: Fix bitcoin blocklist
    services.tor.hiddenServices.bitcoind = mkHiddenService { port = config.services.bitcoind.port; toHost = netns.bitcoind.address; };
    services.bitcoind.extraConfig = ''
      rpcbind=${netns.bitcoind.address}
      rpcbind=127.0.0.1
      rpcallowip=127.0.0.1
    '' + concatMapStrings (s: ''
      rpcallowip=${netns.${s}.address}
    '') netns.bitcoind.availableNetns;

    services.electrs = {
      address = netns.electrs.address;
      extraArgs = "--daemon-rpc-addr=${netns.bitcoind.address}:${toString config.services.bitcoind.rpc.port}";
    };
  };
}
