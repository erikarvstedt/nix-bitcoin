{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.netns;

  mkHiddenService = map: {
    map = [ map ];
    version = 3;
  };

  netns-init-script = pkgs.writeScript "netns-init.sh" ''
    ${pkgs.iproute}/bin/ip link add name br0 type bridge
    ${pkgs.iproute}/bin/ip link set br0 up
    ${pkgs.iproute}/bin/ip addr add 169.254.0.10/24 brd + dev br0
    ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 169.254.0.0/24 -j MASQUERADE
    ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 169.254.0.0/24 -j MASQUERADE
    ${pkgs.sysctl}/bin/sysctl -w net.ipv4.ip_forward=1
  '';
  netns-stop-script = pkgs.writeScript "netns-stop.sh" ''
    ${pkgs.iproute}/bin/ip link del br0
    ${pkgs.sysctl}/bin/sysctl -w net.ipv4.ip_forward=0
  '';
in {
  options.services.netns = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the netns-init service will be installed.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Prerequisites
    networking.dhcpcd.extraConfig = "noipv4ll";
    services.tor.client.socksListenAddress = "169.254.0.10:9050";
    networking.firewall.interfaces.br0.allowedTCPPorts = [ 9050 ];

    # bitcoin: Custom netns configs
    # TODO: Override hiddenServices
    # TODO: Fix bitcoin blocklist
    services.tor.hiddenServices.bitcoind = mkHiddenService { port = config.services.bitcoind.port; toHost = "169.254.0.12"; };
    systemd.services.bitcoind.serviceConfig = {
      NetworkNamespacePath = "/var/run/netns/bitcoind";
    };
    services.bitcoind.extraConfig = ''
      rpcbind=169.254.0.12
      rpcbind=127.0.0.1
      rpcallowip=169.254.0.13
      rpcallowip=169.254.0.14
      rpcallowip=169.254.0.15
      rpcallowip=169.254.0.16
      rpcallowip=169.254.0.17
      rpcallowip=127.0.0.1
    '';

    # clightning: Custom netns configs
    services.tor.hiddenServices.clightning = mkHiddenService { port = config.services.clightning.onionport; toHost = "169.254.0.13"; };
    services.clightning.bitcoin-rpcconnect = "169.254.0.12";
    services.clightning.bind-addr = lib.mkForce "169.254.0.13:${toString config.services.clightning.onionport}";
    systemd.services.clightning.serviceConfig = {
      NetworkNamespacePath = "/var/run/netns/clightning";
    };

    # lnd: Custom netns configs
    # TODO: configure networking for LND
    
    # liquidd: Custom netns configs
    services.tor.hiddenServices.liquidd = mkHiddenService { port = config.services.liquidd.port; toHost = "169.254.0.15"; };
    services.liquidd.extraConfig = lib.mkForce ''
      rpcbind=169.254.0.15
      rpcbind=127.0.0.1
      rpcallowip=169.254.0.15
      rpcallowip=127.0.0.1
      mainchainrpchost=169.254.0.12
      mainchainrpcuser=${config.services.bitcoind.rpcuser}
      mainchainrpcport=8332
    '';
    systemd.services.liquidd.serviceConfig = {
      NetworkNamespacePath = "/var/run/netns/liquidd";
    };

    # electrs: Custom netns configs
    services.tor.hiddenServices.electrs = mkHiddenService {
      port = config.services.electrs.onionport;
      toPort = if config.services.electrs.TLSProxy.enable then config.services.electrs.TLSProxy.port else config.services.electrs.port;
      toHost = "169.254.0.22";
    };
    services.electrs.address = "169.254.0.16";
    services.electrs.extraArgs = "--daemon-rpc-addr=169.254.0.12:8332";
    systemd.services.electrs.serviceConfig = {
      NetworkNamespacePath = "/var/run/netns/electrs";
    };

    # joinmarket: Custom netns configs
    systemd.services.joinmarketd.serviceConfig = {
      NetworkNamespacePath = "/var/run/netns/joinmarket";
    };
    systemd.services.joinmarket-yieldgenerator.serviceConfig = {
      NetworkNamespacePath = "/var/run/netns/joinmarket";
    };

    # spark-wallet: Custom netns configs
    services.tor.hiddenServices.spark-wallet = mkHiddenService { port = 80; toPort = 9737; toHost = "169.254.0.18"; };
    services.spark-wallet.extraArgs = "--host 169.254.0.18 --no-tls";
    systemd.services.spark-wallet.serviceConfig = {
      NetworkNamespacePath = "/var/run/netns/spark-wallet";
    };

    # lightning-charge: Custom netns configs
    services.lightning-charge.extraArgs = "--host 169.254.0.19";
    systemd.services.lightning-charge.serviceConfig = {
      NetworkNamespacePath = "/var/run/netns/lightning-charge";
    };

    # nanopos: Custom netns configs
    services.nanopos.charged-url = "http://169.254.0.19:9112";
    services.nanopos.host = "169.254.0.20";
    systemd.services.nanopos.serviceConfig = {
      NetworkNamespacePath = "/var/run/netns/nanopos";
    };

    # recurring-donations: Custom netns configs
    systemd.services.recurring-donations.serviceConfig = {
      NetworkNamespacePath = "/var/run/netns/recurring-donations";
    };

    # nginx: Custom netns configs
    services.tor.hiddenServices.nginx.map = lib.mkForce [ {port = 80; toHost = "169.254.0.22";} {port = 443; toHost = "169.254.0.22";} ];
    systemd.services.nginx.serviceConfig ={
      NetworkNamespacePath = "/var/run/netns/nginx";
    };

    # Bridge creation
    systemd.services.netns = {
      description = "Create bridge";
      requiredBy = [ "tor.service" ];
      before = [ "tor.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStart = "${pkgs.bash}/bin/bash ${netns-init-script}";
        ExecStop = "${pkgs.bash}/bin/bash ${netns-stop-script}";
      };
    };

    systemd.services.netns-bitcoind = mkIf config.services.bitcoind.enable {
      description = "Create bitcoind namespace";
      requires = [ "netns.service" ];
      after = [ "netns.service" ];
      requiredBy = [ "bitcoind.service" ];
      bindsTo = [ "bitcoind.service" ]; 
      before = [ "bitcoind.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStartPre = "-${pkgs.iproute}/bin/ip netns delete bitcoind";
        ExecStart = [
          "${pkgs.iproute}/bin/ip netns add bitcoind"
          "${pkgs.iproute}/bin/ip -n bitcoind link set lo up"
          "${pkgs.iproute}/bin/ip link add veth1 type veth peer name br-veth1"
          "${pkgs.iproute}/bin/ip link set veth1 netns bitcoind"
          "${pkgs.iproute}/bin/ip -n bitcoind addr add 169.254.0.12/24 dev veth1"
          "${pkgs.iproute}/bin/ip link set br-veth1 up"
          "${pkgs.iproute}/bin/ip -n bitcoind link set veth1 up"
          "${pkgs.iproute}/bin/ip link set br-veth1 master br0"
          "${pkgs.iproute}/bin/ip -n bitcoind route add default via 169.254.0.10"
        ]
        ++ (optionals config.services.bitcoind.enforceTor [ 
          "${pkgs.iproute}/bin/ip netns exec bitcoind ${pkgs.iptables}/bin/iptables -P OUTPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec bitcoind ${pkgs.iptables}/bin/iptables -A OUTPUT -d 127.0.0.1,169.254.0.10 -j ACCEPT"
        ])
        ++ [ 
          "${pkgs.iproute}/bin/ip netns exec bitcoind ${pkgs.iptables}/bin/iptables -P INPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec bitcoind ${pkgs.iptables}/bin/iptables -A INPUT -s 127.0.0.1,169.254.0.10 -j ACCEPT"
        ]
        ++ (optionals config.services.clightning.enable [
          "${pkgs.iproute}/bin/ip netns exec bitcoind ${pkgs.iptables}/bin/iptables -A INPUT -s 169.254.0.13 -j ACCEPT"
          "${pkgs.iproute}/bin/ip netns exec bitcoind ${pkgs.iptables}/bin/iptables -A OUTPUT -d 169.254.0.13 -j ACCEPT"
        ])
        ++ (optionals config.services.lnd.enable [
          "${pkgs.iproute}/bin/ip netns exec bitcoind ${pkgs.iptables}/bin/iptables -A INPUT -s 169.254.0.14 -j ACCEPT"
          "${pkgs.iproute}/bin/ip netns exec bitcoind ${pkgs.iptables}/bin/iptables -A OUTPUT -d 169.254.0.14 -j ACCEPT"
        ])
        ++ (optionals config.services.liquidd.enable [
          "${pkgs.iproute}/bin/ip netns exec bitcoind ${pkgs.iptables}/bin/iptables -A INPUT -s 169.254.0.15 -j ACCEPT"
          "${pkgs.iproute}/bin/ip netns exec bitcoind ${pkgs.iptables}/bin/iptables -A OUTPUT -d 169.254.0.15 -j ACCEPT"
        ])
        ++ (optionals config.services.electrs.enable [
          "${pkgs.iproute}/bin/ip netns exec bitcoind ${pkgs.iptables}/bin/iptables -A INPUT -s 169.254.0.16 -j ACCEPT"
          "${pkgs.iproute}/bin/ip netns exec bitcoind ${pkgs.iptables}/bin/iptables -A OUTPUT -d 169.254.0.16 -j ACCEPT"
        ])
        ++ (optionals config.services.joinmarket.enable [
          "${pkgs.iproute}/bin/ip netns exec bitcoind ${pkgs.iptables}/bin/iptables -A INPUT -s 169.254.0.17 -j ACCEPT"
          "${pkgs.iproute}/bin/ip netns exec bitcoind ${pkgs.iptables}/bin/iptables -A OUTPUT -d 169.254.0.17 -j ACCEPT"
        ]);
        ExecStop = ''
          ${pkgs.iproute}/bin/ip netns delete bitcoind ;\
          ${pkgs.iproute}/bin/ip link del br-veth1
        '';
      };
    };

    systemd.services.netns-clightning = mkIf config.services.clightning.enable {
      description = "Create clightning namespace";
      requires = [ "netns.service" ];
      after = [ "netns.service" ];
      requiredBy = [ "clightning.service" ];
      bindsTo = [ "clightning.service" ];
      before = [ "clightning.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStartPre = "-${pkgs.iproute}/bin/ip netns delete clightning";
        ExecStart = [
          "${pkgs.iproute}/bin/ip netns add clightning"
          "${pkgs.iproute}/bin/ip -n clightning link set lo up"
          "${pkgs.iproute}/bin/ip link add veth2 type veth peer name br-veth2"
          "${pkgs.iproute}/bin/ip link set veth2 netns clightning"
          "${pkgs.iproute}/bin/ip -n clightning addr add 169.254.0.13/24 dev veth2"
          "${pkgs.iproute}/bin/ip link set br-veth2 up"
          "${pkgs.iproute}/bin/ip -n clightning link set veth2 up"
          "${pkgs.iproute}/bin/ip link set br-veth2 master br0"
          "${pkgs.iproute}/bin/ip -n clightning route add default via 169.254.0.10"
        ]
        ++ (optionals config.services.clightning.enforceTor [
          "${pkgs.iproute}/bin/ip netns exec clightning ${pkgs.iptables}/bin/iptables -P OUTPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec clightning ${pkgs.iptables}/bin/iptables -A OUTPUT -d 127.0.0.1,169.254.0.10,169.254.0.12 -j ACCEPT"
        ])
        ++ [
          "${pkgs.iproute}/bin/ip netns exec clightning ${pkgs.iptables}/bin/iptables -P INPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec clightning ${pkgs.iptables}/bin/iptables -A INPUT -s 127.0.0.1,169.254.0.10,169.254.0.12 -j ACCEPT"
        ]
        ++ (optionals config.services.recurring-donations.enable [
          "${pkgs.iproute}/bin/ip netns exec clightning ${pkgs.iptables}/bin/iptables -A INPUT -s 169.254.0.21 -j ACCEPT"
          "${pkgs.iproute}/bin/ip netns exec clightning ${pkgs.iptables}/bin/iptables -A OUTPUT -d 169.254.0.21 -j ACCEPT"
        ]);
        ExecStop = ''
          ${pkgs.iproute}/bin/ip netns delete clightning ;\
          ${pkgs.iproute}/bin/ip link del br-veth2
        '';
      };
    };

    systemd.services.netns-lnd = mkIf config.services.lnd.enable {
      description = "Create lnd namespace";
      requires = [ "netns.service" ];
      after = [ "netns.service" ];
      requiredBy = [ "lnd.service" ];
      bindsTo = [ "lnd.service" ];
      before = [ "lnd.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStartPre = "-${pkgs.iproute}/bin/ip netns delete lnd";
        ExecStart = [
          "${pkgs.iproute}/bin/ip netns add lnd"
          "${pkgs.iproute}/bin/ip -n lnd link set lo up"
          "${pkgs.iproute}/bin/ip link add veth3 type veth peer name br-veth3"
          "${pkgs.iproute}/bin/ip link set veth3 netns lnd"
          "${pkgs.iproute}/bin/ip -n lnd addr add 169.254.0.14/24 dev veth3"
          "${pkgs.iproute}/bin/ip link set br-veth3 up"
          "${pkgs.iproute}/bin/ip -n lnd link set veth3 up"
          "${pkgs.iproute}/bin/ip link set br-veth3 master br0"
          "${pkgs.iproute}/bin/ip -n lnd route add default via 169.254.0.10"
        ]
        ++ (optionals config.services.lnd.enforceTor [
          "${pkgs.iproute}/bin/ip netns exec lnd ${pkgs.iptables}/bin/iptables -P OUTPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec lnd ${pkgs.iptables}/bin/iptables -A OUTPUT -d 127.0.0.1,169.254.0.10,169.254.0.12 -j ACCEPT"
        ])
        ++ [
          "${pkgs.iproute}/bin/ip netns exec lnd ${pkgs.iptables}/bin/iptables -P INPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec lnd ${pkgs.iptables}/bin/iptables -A INPUT -s 127.0.0.1,169.254.0.10,169.254.0.12 -j ACCEPT"
        ];
        ExecStop = ''
          ${pkgs.iproute}/bin/ip netns delete lnd ;\
          ${pkgs.iproute}/bin/ip link del br-veth3
        '';
      };
    };

    systemd.services.netns-liquidd = mkIf config.services.liquidd.enable {
      description = "Create liquidd namespace";
      requires = [ "netns.service" ];
      after = [ "netns.service" ];
      requiredBy = [ "liquidd.service" ];
      bindsTo = [ "liquidd.service" ];
      before = [ "liquidd.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStartPre = "-${pkgs.iproute}/bin/ip netns delete liquidd";
        ExecStart = [
          "${pkgs.iproute}/bin/ip netns add liquidd"
          "${pkgs.iproute}/bin/ip -n liquidd link set lo up"
          "${pkgs.iproute}/bin/ip link add veth4 type veth peer name br-veth4"
          "${pkgs.iproute}/bin/ip link set veth4 netns liquidd"
          "${pkgs.iproute}/bin/ip -n liquidd addr add 169.254.0.15/24 dev veth4"
          "${pkgs.iproute}/bin/ip link set br-veth4 up"
          "${pkgs.iproute}/bin/ip -n liquidd link set veth4 up"
          "${pkgs.iproute}/bin/ip link set br-veth4 master br0"
          "${pkgs.iproute}/bin/ip -n liquidd route add default via 169.254.0.10"
        ]
        ++ (optionals config.services.liquidd.enforceTor [
          "${pkgs.iproute}/bin/ip netns exec liquidd ${pkgs.iptables}/bin/iptables -P OUTPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec liquidd ${pkgs.iptables}/bin/iptables -A OUTPUT -d 127.0.0.1,169.254.0.10,169.254.0.12 -j ACCEPT"
        ])
        ++ [
          "${pkgs.iproute}/bin/ip netns exec liquidd ${pkgs.iptables}/bin/iptables -P INPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec liquidd ${pkgs.iptables}/bin/iptables -A INPUT -s 127.0.0.1,169.254.0.10,169.254.0.12 -j ACCEPT"
        ];
        ExecStop = ''
          ${pkgs.iproute}/bin/ip netns delete liquidd ;\
          ${pkgs.iproute}/bin/ip link del br-veth4
        '';
      };
    };

    systemd.services.netns-electrs = mkIf config.services.electrs.enable {
      description = "Create electrs namespace";
      requires = [ "netns.service" ];
      after = [ "netns.service" ];
      requiredBy = [ "electrs.service" ];
      bindsTo = [ "electrs.service" ];
      before = [ "electrs.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStartPre = "-${pkgs.iproute}/bin/ip netns delete electrs";
        ExecStart = [
          "${pkgs.iproute}/bin/ip netns add electrs"
          "${pkgs.iproute}/bin/ip -n electrs link set lo up"
          "${pkgs.iproute}/bin/ip link add veth5 type veth peer name br-veth5"
          "${pkgs.iproute}/bin/ip link set veth5 netns electrs"
          "${pkgs.iproute}/bin/ip -n electrs addr add 169.254.0.16/24 dev veth5"
          "${pkgs.iproute}/bin/ip link set br-veth5 up"
          "${pkgs.iproute}/bin/ip -n electrs link set veth5 up"
          "${pkgs.iproute}/bin/ip link set br-veth5 master br0"
          "${pkgs.iproute}/bin/ip -n electrs route add default via 169.254.0.10"
        ]
        ++ (optionals config.services.electrs.enforceTor [
          "${pkgs.iproute}/bin/ip netns exec electrs ${pkgs.iptables}/bin/iptables -P OUTPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec electrs ${pkgs.iptables}/bin/iptables -A OUTPUT -d 127.0.0.1,169.254.0.10,169.254.0.12 -j ACCEPT"
        ])
        ++ (optionals config.services.electrs.TLSProxy.enable [
          "${pkgs.iproute}/bin/ip netns exec electrs ${pkgs.iptables}/bin/iptables -A INPUT -s 169.254.0.22 -j ACCEPT"
          "${pkgs.iproute}/bin/ip netns exec electrs ${pkgs.iptables}/bin/iptables -A OUTPUT -d 169.254.0.22 -j ACCEPT"
        ])
        ++ [
          "${pkgs.iproute}/bin/ip netns exec electrs ${pkgs.iptables}/bin/iptables -P INPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec electrs ${pkgs.iptables}/bin/iptables -A INPUT -s 127.0.0.1,169.254.0.10,169.254.0.12 -j ACCEPT"
        ];
        ExecStop = ''
          ${pkgs.iproute}/bin/ip netns delete electrs ;\
          ${pkgs.iproute}/bin/ip link del br-veth5
        '';
      };
    };

    systemd.services.netns-joinmarket = mkIf config.services.joinmarket.enable {
      description = "Create joinmarket namespace";
      requires = [ "netns.service" ];
      after = [ "netns.service" ];
      requiredBy = [ "joinmarketd.service" ];
      bindsTo = [ "joinmarketd.service" ];
      before = [ "joinmarketd.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStartPre = "-${pkgs.iproute}/bin/ip netns delete joinmarket";
        ExecStart = [
          "${pkgs.iproute}/bin/ip netns add joinmarket"
          "${pkgs.iproute}/bin/ip -n joinmarket link set lo up"
          "${pkgs.iproute}/bin/ip link add veth6 type veth peer name br-veth6"
          "${pkgs.iproute}/bin/ip link set veth6 netns joinmarket"
          "${pkgs.iproute}/bin/ip -n joinmarket addr add 169.254.0.17/24 dev veth6"
          "${pkgs.iproute}/bin/ip link set br-veth6 up"
          "${pkgs.iproute}/bin/ip -n joinmarket link set veth6 up"
          "${pkgs.iproute}/bin/ip link set br-veth6 master br0"
          "${pkgs.iproute}/bin/ip -n joinmarket route add default via 169.254.0.10"
        ]
        ++ [
          "${pkgs.iproute}/bin/ip netns exec joinmarket ${pkgs.iptables}/bin/iptables -P OUTPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec joinmarket ${pkgs.iptables}/bin/iptables -A OUTPUT -d 127.0.0.1,169.254.0.10,169.254.0.12 -j ACCEPT"
          "${pkgs.iproute}/bin/ip netns exec joinmarket ${pkgs.iptables}/bin/iptables -P INPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec joinmarket ${pkgs.iptables}/bin/iptables -A INPUT -s 127.0.0.1,169.254.0.10,169.254.0.12 -j ACCEPT"
        ];
        ExecStop = ''
          ${pkgs.iproute}/bin/ip netns delete joinmarket ;\
          ${pkgs.iproute}/bin/ip link del br-veth6
        '';
      };
    };

    systemd.services.netns-spark-wallet = mkIf config.services.spark-wallet.enable {
      description = "Create spark-wallet namespace";
      requires = [ "netns.service" ];
      after = [ "netns.service" ];
      requiredBy = [ "spark-wallet.service" ];
      bindsTo = [ "spark-wallet.service" ];
      before = [ "spark-wallet.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStartPre = "-${pkgs.iproute}/bin/ip netns delete spark-wallet";
        ExecStart = [
          "${pkgs.iproute}/bin/ip netns add spark-wallet"
          "${pkgs.iproute}/bin/ip -n spark-wallet link set lo up"
          "${pkgs.iproute}/bin/ip link add veth7 type veth peer name br-veth7"
          "${pkgs.iproute}/bin/ip link set veth7 netns spark-wallet"
          "${pkgs.iproute}/bin/ip -n spark-wallet addr add 169.254.0.18/24 dev veth7"
          "${pkgs.iproute}/bin/ip link set br-veth7 up"
          "${pkgs.iproute}/bin/ip -n spark-wallet link set veth7 up"
          "${pkgs.iproute}/bin/ip link set br-veth7 master br0"
          "${pkgs.iproute}/bin/ip -n spark-wallet route add default via 169.254.0.10"
        ]
        ++ [
          "${pkgs.iproute}/bin/ip netns exec spark-wallet ${pkgs.iptables}/bin/iptables -P OUTPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec spark-wallet ${pkgs.iptables}/bin/iptables -A OUTPUT -d 127.0.0.1,169.254.0.10 -j ACCEPT"
          "${pkgs.iproute}/bin/ip netns exec spark-wallet ${pkgs.iptables}/bin/iptables -P INPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec spark-wallet ${pkgs.iptables}/bin/iptables -A INPUT -s 127.0.0.1,169.254.0.10 -j ACCEPT"
        ];
        ExecStop = ''
          ${pkgs.iproute}/bin/ip netns delete spark-wallet ;\
          ${pkgs.iproute}/bin/ip link del br-veth7
        '';
      };
    };

    systemd.services.netns-lightning-charge = mkIf config.services.lightning-charge.enable {
      description = "Create lightning-charge namespace";
      requires = [ "netns.service" ];
      after = [ "netns.service" ];
      requiredBy = [ "lightning-charge.service" ];
      bindsTo = [ "lightning-charge.service" ];
      before = [ "lightning-charge.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStartPre = "-${pkgs.iproute}/bin/ip netns delete lightning-charge";
        ExecStart = [
          "${pkgs.iproute}/bin/ip netns add lightning-charge"
          "${pkgs.iproute}/bin/ip -n lightning-charge link set lo up"
          "${pkgs.iproute}/bin/ip link add veth8 type veth peer name br-veth8"
          "${pkgs.iproute}/bin/ip link set veth8 netns lightning-charge"
          "${pkgs.iproute}/bin/ip -n lightning-charge addr add 169.254.0.19/24 dev veth8"
          "${pkgs.iproute}/bin/ip link set br-veth8 up"
          "${pkgs.iproute}/bin/ip -n lightning-charge link set veth8 up"
          "${pkgs.iproute}/bin/ip link set br-veth8 master br0"
          "${pkgs.iproute}/bin/ip -n lightning-charge route add default via 169.254.0.10"
        ]
        ++ [
          "${pkgs.iproute}/bin/ip netns exec lightning-charge ${pkgs.iptables}/bin/iptables -P OUTPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec lightning-charge ${pkgs.iptables}/bin/iptables -A OUTPUT -d 127.0.0.1,169.254.0.10,169.254.0.20 -j ACCEPT"
          "${pkgs.iproute}/bin/ip netns exec lightning-charge ${pkgs.iptables}/bin/iptables -P INPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec lightning-charge ${pkgs.iptables}/bin/iptables -A INPUT -s 127.0.0.1,169.254.0.10,169.254.0.20 -j ACCEPT"
        ];
        ExecStop = ''
          ${pkgs.iproute}/bin/ip netns delete lightning-charge ;\
          ${pkgs.iproute}/bin/ip link del br-veth8
        '';
      };
    };

    systemd.services.netns-nanopos = mkIf config.services.nanopos.enable {
      description = "Create nanopos namespace";
      requires = [ "netns.service" ];
      after = [ "netns.service" ];
      requiredBy = [ "nanopos.service" ];
      bindsTo = [ "nanopos.service" ];
      before = [ "nanopos.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStartPre = "-${pkgs.iproute}/bin/ip netns delete nanopos";
        ExecStart = [
          "${pkgs.iproute}/bin/ip netns add nanopos"
          "${pkgs.iproute}/bin/ip -n nanopos link set lo up"
          "${pkgs.iproute}/bin/ip link add veth9 type veth peer name br-veth9"
          "${pkgs.iproute}/bin/ip link set veth9 netns nanopos"
          "${pkgs.iproute}/bin/ip -n nanopos addr add 169.254.0.20/24 dev veth9"
          "${pkgs.iproute}/bin/ip link set br-veth9 up"
          "${pkgs.iproute}/bin/ip -n nanopos link set veth9 up"
          "${pkgs.iproute}/bin/ip link set br-veth9 master br0"
          "${pkgs.iproute}/bin/ip -n nanopos route add default via 169.254.0.10"
        ]
        ++ [
          "${pkgs.iproute}/bin/ip netns exec nanopos ${pkgs.iptables}/bin/iptables -P OUTPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec nanopos ${pkgs.iptables}/bin/iptables -A OUTPUT -d 127.0.0.1,169.254.0.10,169.254.0.19,169.254.0.22 -j ACCEPT"
          "${pkgs.iproute}/bin/ip netns exec nanopos ${pkgs.iptables}/bin/iptables -P INPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec nanopos ${pkgs.iptables}/bin/iptables -A INPUT -s 127.0.0.1,169.254.0.10,169.254.0.19,169.254.0.22 -j ACCEPT"
        ];
        ExecStop = ''
          ${pkgs.iproute}/bin/ip netns delete nanopos ;\
          ${pkgs.iproute}/bin/ip link del br-veth9
        '';
      };
    };

    systemd.services.netns-recurring-donations = mkIf config.services.recurring-donations.enable {
      description = "Create recurring-donations namespace";
      requires = [ "netns.service" ];
      after = [ "netns.service" ];
      requiredBy = [ "recurring-donations.service" ];
      bindsTo = [ "recurring-donations.service" ];
      before = [ "recurring-donations.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStartPre = "-${pkgs.iproute}/bin/ip netns delete recurring-donations";
        ExecStart = [
          "${pkgs.iproute}/bin/ip netns add recurring-donations"
          "${pkgs.iproute}/bin/ip -n recurring-donations link set lo up"
          "${pkgs.iproute}/bin/ip link add veth10 type veth peer name br-veth10"
          "${pkgs.iproute}/bin/ip link set veth10 netns recurring-donations"
          "${pkgs.iproute}/bin/ip -n recurring-donations addr add 169.254.0.21/24 dev veth10"
          "${pkgs.iproute}/bin/ip link set br-veth10 up"
          "${pkgs.iproute}/bin/ip -n recurring-donations link set veth10 up"
          "${pkgs.iproute}/bin/ip link set br-veth10 master br0"
          "${pkgs.iproute}/bin/ip -n recurring-donations route add default via 169.254.0.10"
        ]
        ++ [
          "${pkgs.iproute}/bin/ip netns exec recurring-donations ${pkgs.iptables}/bin/iptables -P OUTPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec recurring-donations ${pkgs.iptables}/bin/iptables -A OUTPUT -d 127.0.0.1,169.254.0.10 -j ACCEPT"
          "${pkgs.iproute}/bin/ip netns exec recurring-donations ${pkgs.iptables}/bin/iptables -P INPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec recurring-donations ${pkgs.iptables}/bin/iptables -A INPUT -s 127.0.0.1,169.254.0.10 -j ACCEPT"
        ];
        ExecStop = ''
          ${pkgs.iproute}/bin/ip netns delete recurring-donations ;\
          ${pkgs.iproute}/bin/ip link del br-veth10
        '';
      };
    };

    systemd.services.netns-nginx = mkIf config.services.nginx.enable {
      description = "Create nginx namespace";
      requires = [ "netns.service" ];
      after = [ "netns.service" ];
      requiredBy = [ "nginx.service" ];
      bindsTo = [ "nginx.service" ];
      before = [ "nginx.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStartPre = "-${pkgs.iproute}/bin/ip netns delete nginx";
        ExecStart = [
          "${pkgs.iproute}/bin/ip netns add nginx"
          "${pkgs.iproute}/bin/ip -n nginx link set lo up"
          "${pkgs.iproute}/bin/ip link add veth11 type veth peer name br-veth11"
          "${pkgs.iproute}/bin/ip link set veth11 netns nginx"
          "${pkgs.iproute}/bin/ip -n nginx addr add 169.254.0.22/24 dev veth11"
          "${pkgs.iproute}/bin/ip link set br-veth11 up"
          "${pkgs.iproute}/bin/ip -n nginx link set veth11 up"
          "${pkgs.iproute}/bin/ip link set br-veth11 master br0"
          "${pkgs.iproute}/bin/ip -n nginx route add default via 169.254.0.10"
        ]
        ++ [
          "${pkgs.iproute}/bin/ip netns exec nginx ${pkgs.iptables}/bin/iptables -P OUTPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec nginx ${pkgs.iptables}/bin/iptables -A OUTPUT -d 127.0.0.1,169.254.0.10 -j ACCEPT"
          "${pkgs.iproute}/bin/ip netns exec nginx ${pkgs.iptables}/bin/iptables -P INPUT DROP"
          "${pkgs.iproute}/bin/ip netns exec nginx ${pkgs.iptables}/bin/iptables -A INPUT -s 127.0.0.1,169.254.0.10 -j ACCEPT"
        ]
        ++ (optionals config.services.electrs.enable [
          "${pkgs.iproute}/bin/ip netns exec nginx ${pkgs.iptables}/bin/iptables -A INPUT -s 169.254.0.16 -j ACCEPT"
          "${pkgs.iproute}/bin/ip netns exec nginx ${pkgs.iptables}/bin/iptables -A OUTPUT -d 169.254.0.16 -j ACCEPT"
        ])
        ++ (optionals config.services.nanopos.enable [
          "${pkgs.iproute}/bin/ip netns exec nginx ${pkgs.iptables}/bin/iptables -A INPUT -s 169.254.0.20 -j ACCEPT"
          "${pkgs.iproute}/bin/ip netns exec nginx ${pkgs.iptables}/bin/iptables -A OUTPUT -d 169.254.0.20 -j ACCEPT"
        ]);
        ExecStop = ''
          ${pkgs.iproute}/bin/ip netns delete nginx ;\
          ${pkgs.iproute}/bin/ip link del br-veth11
        '';
      };
    };


  };
}
