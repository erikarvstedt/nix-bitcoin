{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.joinmarket;
  inherit (config) nix-bitcoin-services;
  secretsDir = config.nix-bitcoin.secretsDir;
  configFile = pkgs.writeText "config" ''
    [DAEMON]
    no_daemon = 0
    daemon_port = 27183
    daemon_host = localhost
    use_ssl = false

    [BLOCKCHAIN]
    blockchain_source = bitcoin-rpc
    network = mainnet
    rpc_host = ${cfg.rpc_host}
    rpc_port = 8332
    rpc_user = ${config.services.bitcoind.rpc.users.privileged.name}
    rpc_password =

    [MESSAGING:server1]
    host = darksci3bfoka7tw.onion
    channel = joinmarket-pit
    port = 6697
    usessl = true
    socks5 = true
    socks5_host = ${builtins.head (builtins.split ":" config.services.tor.client.socksListenAddress)}
    socks5_port = 9050

    [MESSAGING:server2]
    host = ncwkrwxpq2ikcngxq3dy2xctuheniggtqeibvgofixpzvrwpa77tozqd.onion
    channel = joinmarket-pit
    port = 6697
    usessl = false
    socks5 = true
    socks5_host = localhost
    socks5_port = 9050

    [LOGGING]
    console_log_level = INFO
    color = false

    [POLICY]
    segwit = true
    native = false
    merge_algorithm = default
    tx_fees = 3
    absurd_fee_per_kb = 350000
    tx_broadcast = self
    minimum_makers = 4
    max_sats_freeze_reuse = -1
    taker_utxo_retries = 3
    taker_utxo_age = 5
    taker_utxo_amtpercent = 20
    accept_commitment_broadcasts = 1
    commit_file_location = cmtdata/commitments.json
  '';
in {
  options.services.joinmarket = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, JoinMarket will be installed.
      '';
    };
    yieldgenerator = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the yield generator bot will be enabled.
      '';
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/joinmarket";
      description = "The data directory for JoinMarket.";
    };
    user = mkOption {
      type = types.str;
      default = "joinmarket";
      description = "The user as which to run JoinMarket.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run JoinMarket.";
    };
    rpc_host = mkOption {
      type = types.str;
      default = "localhost";
      description = ''
        The address that the daemon will try to connect to bitcoind under.
      '';
    };
    add-utxo = mkOption {
      default = pkgs.writeScriptBin "add-utxo.py"
      ''
        cd ${cfg.dataDir} && ${cfg.cliExec} sudo -u ${cfg.user} ${pkgs.nix-bitcoin.joinmarket}/bin/add-utxo.py --datadir=${cfg.dataDir} "$@"
      ''; # Script needs to be ${cfg.cliExec}uted in directory, because it needs to create 'logs' dir
      description = ''
        Script to add one or more utxos to the list that can be used to
        make commitments for anti-snooping.
      '';
    };
    convert_old_wallet = mkOption {
      default = pkgs.writeScriptBin "convert_old_wallet.py"
      ''
        cd ${cfg.dataDir} && ${cfg.cliExec} sudo -u ${cfg.user} ${pkgs.nix-bitcoin.joinmarket}/bin/convert_old_wallet.py --datadir=${cfg.dataDir} "$@"
      '';
      description = ''
        Script to convert old JoinMarket json wallet format to new jmdat
        format.
      '';
    };
    receive-payjoin = mkOption {
      default = pkgs.writeScriptBin "receive-payjoin.py"
      ''
        cd ${cfg.dataDir} && ${cfg.cliExec} sudo -u ${cfg.user} ${pkgs.nix-bitcoin.joinmarket}/bin/receive-payjoin.py --datadir=${cfg.dataDir} "$@"
      '';
      description = ''
        Script to receive payjoins.
      '';
    };
    sendpayment = mkOption {
      default = pkgs.writeScriptBin "sendpayment.py"
      ''
        cd ${cfg.dataDir} && ${cfg.cliExec} sudo -u ${cfg.user} ${pkgs.nix-bitcoin.joinmarket}/bin/sendpayment.py --datadir=${cfg.dataDir} "$@"
      '';
      description = ''
        Script to send a single payment from a given mixing depth of
        your wallet to an given address using coinjoin.
      '';
    };
    sendtomany = mkOption {
      default = pkgs.writeScriptBin "sendtomany.py"
      ''
        cd ${cfg.dataDir} && ${cfg.cliExec} sudo -u ${cfg.user} ${pkgs.nix-bitcoin.joinmarket}/bin/sendtomany.py --datadir=${cfg.dataDir} "$@"
      '';
      description = ''
        Script to create multiple utxos from one.
      '';
    };
    tumbler = mkOption {
      default = pkgs.writeScriptBin "tumbler.py"
      ''
        cd ${cfg.dataDir} && ${cfg.cliExec} sudo -u ${cfg.user} ${pkgs.nix-bitcoin.joinmarket}/bin/tumbler.py --datadir=${cfg.dataDir} "$@"
      '';
      description = ''
        Script to send bitcoins to many different addresses using
        coinjoin in an attempt to break the link between them.
      '';
    };
    wallet-tool = mkOption {
      default = pkgs.writeScriptBin "wallet-tool.py"
      ''
        cd ${cfg.dataDir} && ${cfg.cliExec} sudo -u ${cfg.user} ${pkgs.nix-bitcoin.joinmarket}/bin/wallet-tool.py --datadir=${cfg.dataDir} "$@"
      '';
      description = ''
        Script to monitor and manage your JoinMarket wallet.
      '';
    };
    inherit (nix-bitcoin-services) cliExec;
  };

  config = mkIf cfg.enable (mkMerge [{
    environment.systemPackages = [
      pkgs.nix-bitcoin.joinmarket
      (hiPrio cfg.add-utxo)
      (hiPrio cfg.convert_old_wallet)
      (hiPrio cfg.receive-payjoin)
      (hiPrio cfg.sendpayment)
      (hiPrio cfg.sendtomany)
      (hiPrio cfg.tumbler)
      (hiPrio cfg.wallet-tool)
      pkgs.screen
    ];
    users.users.${cfg.user} = {
        description = "joinmarket User";
        group = "${cfg.group}";
        home = cfg.dataDir;
    };
    users.groups.${cfg.group} = {};

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.joinmarket = {
      description = "Communication server, needs to run to use any JM script";
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      preStart = ''
        # Create JoinMarket directory structure
        mkdir -m 0770 -p ${cfg.dataDir}/{logs,wallets,cmtdata}
        install -m 640 ${configFile} ${cfg.dataDir}/joinmarket.cfg
        # PermissionsStartOnly creates files as root
        chown -R '${cfg.user}:${cfg.group}' '${cfg.dataDir}'
        sed -i "s/rpc_password =/rpc_password = $(cat ${config.nix-bitcoin.secretsDir}/bitcoin-rpcpassword-privileged)/g" '${cfg.dataDir}/joinmarket.cfg'
      '';
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        PermissionsStartOnly = "true"; # Needed to read rpcpassword-privileged
        ExecStart = "${pkgs.nix-bitcoin.joinmarket}/bin/joinmarketd.py";
        User = "${cfg.user}";
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = "${cfg.dataDir}";
      } // nix-bitcoin-services.allowTor;
    };
  }

  (mkIf cfg.yieldgenerator {
    nix-bitcoin.secrets.jm-wallet-password.user = cfg.user;

    systemd.services.joinmarket-yieldgenerator = {
      enable = true;
      description = "CoinJoin maker bot to gain privacy and passively generate income";
      requires = [ "joinmarket.service" ];
      after = [ "joinmarket.service" ];
      preStart = ''
        jmwalletpassword=$(cat ${secretsDir}/jm-wallet-password)
        echo "echo -n $jmwalletpassword | ${pkgs.nix-bitcoin.joinmarket}/bin/yg-privacyenhanced.py --datadir=${cfg.dataDir} --wallet-password-stdin wallet.jmdat" > /run/joinmarket-yieldgenerator/startscript.sh
      '';
      serviceConfig = nix-bitcoin-services.defaultHardening // rec {
        WorkingDirectory = "${cfg.dataDir}";
        RuntimeDirectory = "joinmarket-yieldgenerator";
        RuntimeDirectoryMode = "700";
        PermissionsStartOnly = "true";
        ExecStart = "${pkgs.bash}/bin/bash /run/${RuntimeDirectory}/startscript.sh";
        User = "${cfg.user}";
        ReadWritePaths = "${cfg.dataDir}";
      } // nix-bitcoin-services.allowTor;
    };
  })
  ]);
}
