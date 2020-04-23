{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.joinmarket;
  inherit (config) nix-bitcoin-services;
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
      description = "The data directory for joinmarket.";
    };
    user = mkOption {
      type = types.str;
      default = "joinmarket";
      description = "The user as which to run joinmarket.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run joinmarket.";
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
        cd ${cfg.dataDir} && exec sudo -u ${cfg.user} ${pkgs.nix-bitcoin.joinmarket}/bin/add-utxo.py --datadir=${cfg.dataDir} "$@"
      ''; # Script needs to be executed in directory, because it needs to create 'logs' dir
      description = ''
        Script to add one or more utxos to the list that can be used to
        make commitments for anti-snooping.
      '';
    };
    convert_old_wallet = mkOption {
      default = pkgs.writeScriptBin "convert_old_wallet.py"
      ''
        cd ${cfg.dataDir} && exec sudo -u ${cfg.user} ${pkgs.nix-bitcoin.joinmarket}/bin/convert_old_wallet.py --datadir=${cfg.dataDir} "$@"
      '';
      description = ''
        Script to convert old joinmarket json wallet format to new jmdat
        format.
      '';
    };
    receive-payjoin = mkOption {
      default = pkgs.writeScriptBin "receive-payjoin.py"
      ''
        cd ${cfg.dataDir} && exec sudo -u ${cfg.user} ${pkgs.nix-bitcoin.joinmarket}/bin/receive-payjoin.py --datadir=${cfg.dataDir} "$@"
      '';
      description = ''
        Script to receive payjoins.
      '';
    };
    sendpayment = mkOption {
      default = pkgs.writeScriptBin "sendpayment.py"
      ''
        cd ${cfg.dataDir} && exec sudo -u ${cfg.user} ${pkgs.nix-bitcoin.joinmarket}/bin/sendpayment.py --datadir=${cfg.dataDir} "$@"
      '';
      description = ''
        Script to send a single payment from a given mixing depth of
        your wallet to an given address using coinjoin.
      '';
    };
    sendtomany = mkOption {
      default = pkgs.writeScriptBin "sendtomany.py"
      ''
        cd ${cfg.dataDir} && exec sudo -u ${cfg.user} ${pkgs.nix-bitcoin.joinmarket}/bin/sendtomany.py --datadir=${cfg.dataDir} "$@"
      '';
      description = ''
        Script to create multiple utxos from one.
      '';
    };
    tumbler = mkOption {
      default = pkgs.writeScriptBin "tumbler.py"
      ''
        cd ${cfg.dataDir} && exec sudo -u ${cfg.user} ${pkgs.nix-bitcoin.joinmarket}/bin/tumbler.py --datadir=${cfg.dataDir} "$@"
      '';
      description = ''
        Script to send bitcoins to many different addresses using
        coinjoin in an attempt to break the link between them.
      '';
    };
    wallet-tool = mkOption {
      default = pkgs.writeScriptBin "wallet-tool.py"
      ''
        cd ${cfg.dataDir} && exec sudo -u ${cfg.user} ${pkgs.nix-bitcoin.joinmarket}/bin/wallet-tool.py --datadir=${cfg.dataDir} "$@"
      '';
      description = ''
        Script to monitor and manage your Joinmarket wallet.
      '';
    };
  };

  config = mkIf cfg.enable {
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

    # Communication server, needs to run to use any JM script
    systemd.services.joinmarket = {
      description = "JoinMarket Daemon Service";
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      preStart = ''
        # Create JoinMarket directory structure
        mkdir -m 0770 -p ${cfg.dataDir}/{logs,wallets,cmtdata}
        cp ${configFile} ${cfg.dataDir}/joinmarket.cfg
        chown -R '${cfg.user}:${cfg.group}' '${cfg.dataDir}'
        chmod u=rw,g=r,o= ${cfg.dataDir}/joinmarket.cfg
        sed -i "s/rpc_password =/rpc_password = $(cat ${config.nix-bitcoin.secretsDir}/bitcoin-rpcpassword-privileged)/g" '${cfg.dataDir}/joinmarket.cfg'
      '';
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        PermissionsStartOnly = "true";
        ExecStart = "${pkgs.nix-bitcoin.joinmarket}/bin/joinmarketd.py";
        User = "${cfg.user}";
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = "${cfg.dataDir}";
      } // nix-bitcoin-services.allowTor;
    };

    systemd.services.joinmarket-yieldgenerator = nix-bitcoin-services.defaultHardening // {
      enable = if cfg.yieldgenerator then true else false;
      description = "JoinMarket Yield Generator Service";
      requires = [ "joinmarket.service" ];
      after = [ "joinmarket.service" ];
      serviceConfig = {
        WorkingDirectory = "${cfg.dataDir}";
        PermissionsStartOnly = "true";
        ExecStart = "${pkgs.nix-bitcoin.joinmarket}/bin/yg-privacyenhanced.py --datadir=${cfg.dataDir} --wallet-password-stdin wallet.jmdat";
        User = "${cfg.user}";
        ReadWritePaths = "${cfg.dataDir}";
        StandardInput = "data";
        StandardInputText = "test";
      } // nix-bitcoin-services.allowTor;
    };
  };
}
