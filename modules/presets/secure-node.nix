{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services;

  operatorName = config.nix-bitcoin.operatorName;

  mkHiddenService = map: {
    map = [ map ];
    version = 3;
  };
in {
  imports = [
    ../modules.nix
    ../nodeinfo.nix
    ../nix-bitcoin-webindex.nix
  ];

  options = {
    services.clightning.onionport = mkOption {
      type = types.ints.u16;
      default = 9735;
      description = "Port on which to listen for tor client connections.";
    };
    services.electrs.onionport = mkOption {
      type = types.ints.u16;
      default = 50002;
      description = "Port on which to listen for tor client connections.";
    };
    nix-bitcoin.operatorName = mkOption {
      type = types.str;
      default = "operator";
      description = "Less-privileged user's name.";
    };
  };

  config =  {
    # For backwards compatibility only
    nix-bitcoin.secretsDir = mkDefault "/secrets";

    networking.firewall.enable = true;

    # Tor
    services.tor = {
      enable = true;
      client.enable = true;
      # LND uses ControlPort to create onion services
      controlPort = mkIf cfg.lnd.enable 9051;

      hiddenServices.sshd = mkHiddenService { port = 22; };
    };

    # Network Namespaces
    services.netns = {
      enable = true;
      bridge = {
        ipAddress = "169.254.0.10";
      };
      # TODO: Operator namespace or `ip netns exec` commands
      bitcoind = {
        ipAddress = "169.254.0.12";
        # if services.availableNetns.enable implemented in netns-chef.nix
        availableNetns = [ "clightning" "lnd" "liquidd" "electrs" "joinmarket" ];
      };
      clightning = {
        ipAddress = "169.254.0.13";
        # services communicate with clightning over lightning-rpc socket
        availableNetns = [ "bitcoind" ];
      };
      lnd = {
        ipAddress = "169.254.0.14";
        availableNetns = [ "bitcoind" ];
      };
      liquidd = {
        ipAddress = "169.254.0.15";
        availableNetns = [ "bitcoind" ];
      };
      electrs = {
        ipAddress = "169.254.0.16";
        availableNetns = [ "bitcoind" ]
        ++ ( optionals config.services.electrs.TLSProxy.enable [ "nginx" ]);
      };
      joinmarket = {
        ipAddress = "169.254.0.17";
        availableNetns = [ "bitcoind" ];
      };
      spark-wallet = {
        ipAddress = "169.254.0.18";
        # communicates with clightning over lightning-rpc socket
        availableNetns = [];
        # TODO: Implement config.services.spark-wallet.enforceTor
      };
      lightning-charge = {
        ipAddress = "169.254.0.19";
        # communicates with clightning over lightning-rpc socket
        availableNetns = [ "nanopos" ];
        # TODO: Implement config.services.lightning-charge.enforceTor
      };
      nanopos = {
        ipAddress = "169.254.0.20";
        # communicates with clightning over lightning-rpc socket
        availableNetns = [ "nginx" "lightning-charge" ];
        # TODO: Implement config.services.nanopos.enforceTor
      };
      recurring-donations = {
        ipAddress = "172.0.18.21";
        # communicates with clightning over lightning-rpc socket
        availableNetns = [];
        # TODO: Implement config.services.recurring-donations.enforceTor
      };
      nginx = {
        ipAddress = "172.0.18.22";
        availableNetns = [ "electrs" "nanopos" ];
        # TODO: Modularize nginx and implement cfg.enforceTor
      };
    };


    # bitcoind
    services.bitcoind = {
      enable = true;
      listen = true;
      dataDirReadableByGroup = mkIf cfg.electrs.high-memory true;
      proxy = cfg.tor.client.socksListenAddress;
      enforceTor = true;
      port = 8333;
      assumevalid = "00000000000000000000e5abc3a74fe27dc0ead9c70ea1deb456f11c15fd7bc6";
      addnodes = [ "ecoc5q34tmbq54wl.onion" ];
      discover = false;
      addresstype = "bech32";
      prune = 0;
      dbCache = 1000;
    };
    services.tor.hiddenServices.bitcoind = mkHiddenService { port = cfg.bitcoind.port; };

    # clightning
    services.clightning = {
      bitcoin-rpcuser = cfg.bitcoind.rpcuser;
      proxy = cfg.tor.client.socksListenAddress;
      enforceTor = true;
      always-use-proxy = true;
      bind-addr = "127.0.0.1:${toString cfg.clightning.onionport}";
    };
    services.tor.hiddenServices.clightning = mkHiddenService { port = cfg.clightning.onionport; };

    # lnd
    services.lnd.enforceTor = true;

    # liquidd
    services.liquidd = {
      rpcuser = "liquidrpc";
      prune = 1000;
      extraConfig = ''
        mainchainrpcuser=${cfg.bitcoind.rpcuser}
        mainchainrpcport=8332
      '';
      validatepegin = true;
      listen = true;
      proxy = cfg.tor.client.socksListenAddress;
      enforceTor = true;
      port = 7042;
    };
    services.tor.hiddenServices.liquidd = mkHiddenService { port = cfg.liquidd.port; };

    # electrs
    services.electrs = {
      port = 50001;
      enforceTor = true;
      TLSProxy.enable = true;
      TLSProxy.port = 50003;
    };
    services.tor.hiddenServices.electrs = mkHiddenService {
      port = cfg.electrs.onionport;
      toPort = if cfg.electrs.TLSProxy.enable then cfg.electrs.TLSProxy.port else cfg.electrs.port;
    };

    services.spark-wallet.onion-service = true;

    services.nix-bitcoin-webindex.enforceTor = true;

    # joinmarket
    services.joinmarket.bitcoin-rpcuser = cfg.bitcoind.rpcuser;

    environment.systemPackages = with pkgs; [
      tor
      jq
      qrencode
    ];

    # Create operator user which can access the node's services
    users.users.${operatorName} = {
      isNormalUser = true;
      extraGroups = [
          "systemd-journal"
          cfg.bitcoind.group
        ]
        ++ (optionals cfg.clightning.enable [ "clightning" ])
        ++ (optionals cfg.lnd.enable [ "lnd" ])
        ++ (optionals cfg.liquidd.enable [ cfg.liquidd.group ])
        ++ (optionals (cfg.hardware-wallets.ledger || cfg.hardware-wallets.trezor)
            [ cfg.hardware-wallets.group ])
        ++ (optionals cfg.joinmarket.enable [ "joinmarket" ]);
      openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;
    };
    # Give operator access to onion hostnames
    services.onion-chef.enable = true;
    services.onion-chef.access.${operatorName} = [ "bitcoind" "clightning" "nginx" "liquidd" "spark-wallet" "electrs" "sshd" ];

    security.sudo.configFile =
     (optionalString cfg.lnd.enable ''
       ${operatorName}    ALL=(lnd) NOPASSWD: ALL
     '') +
     (optionalString cfg.joinmarket.enable ''
       ${operatorName}    ALL=(joinmarket) NOPASSWD: ALL
     '');

    # Enable nixops ssh for operator (`nixops ssh operator@mynode`) on nixops-vbox deployments
    systemd.services.get-vbox-nixops-client-key =
      mkIf (builtins.elem ".vbox-nixops-client-key" config.services.openssh.authorizedKeysFiles) {
        postStart = ''
          cp "${config.users.users.root.home}/.vbox-nixops-client-key" "${config.users.users.${operatorName}.home}"
        '';
      };
  };
}
