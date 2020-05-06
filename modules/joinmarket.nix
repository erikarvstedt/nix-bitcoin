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
    rpc_host = localhost
    rpc_port = 8332
    rpc_user = ${cfg.bitcoin-rpcuser}
    rpc_password =

    [MESSAGING:server1]
    host = darksci3bfoka7tw.onion
    channel = joinmarket-pit
    port = 6697
    usessl = true
    socks5 = true
    socks5_host = localhost
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
    color = true

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
    bitcoin-rpcuser = mkOption {
      type = types.str;
      description = ''
        Bitcoin RPC user
      '';
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/joinmarket";
      description = "The data directory for joinmarket.";
    };
    add-utxo = mkOption {
      readOnly = true;
      default = pkgs.writeScriptBin "add-utxo.py"
      ''
        cd ${cfg.dataDir} && exec sudo -u joinmarket ${pkgs.nix-bitcoin.joinmarket}/bin/add-utxo.py --datadir=${cfg.dataDir} "$@"
      ''; # Script needs to be executed in directory, because it needs to create 'logs' dir
      description = ''
        Script to add one or more utxos to the list that can be used to
        make commitments for anti-snooping.
      '';
    };
    convert_old_wallet = mkOption {
      readOnly = true;
      default = pkgs.writeScriptBin "convert_old_wallet.py"
      ''
        cd ${cfg.dataDir} && exec sudo -u joinmarket ${pkgs.nix-bitcoin.joinmarket}/bin/convert_old_wallet.py --datadir=${cfg.dataDir} "$@"
      '';
      description = ''
        Script to convert old joinmarket json wallet format to new jmdat
        format.
      '';
    };
    receive-payjoin = mkOption {
      readOnly = true;
      default = pkgs.writeScriptBin "receive-payjoin.py"
      ''
        cd ${cfg.dataDir} && exec sudo -u joinmarket ${pkgs.nix-bitcoin.joinmarket}/bin/receive-payjoin.py --datadir=${cfg.dataDir} "$@"
      '';
      description = ''
        Script to receive payjoins.
      '';
    };
    sendpayment = mkOption {
      readOnly = true;
      default = pkgs.writeScriptBin "sendpayment.py"
      ''
        cd ${cfg.dataDir} && exec sudo -u joinmarket ${pkgs.nix-bitcoin.joinmarket}/bin/sendpayment.py --datadir=${cfg.dataDir} "$@"
      '';
      description = ''
        Script to send a single payment from a given mixing depth of
        your wallet to an given address using coinjoin.
      '';
    };
    sendtomany = mkOption {
      readOnly = true;
      default = pkgs.writeScriptBin "sendtomany.py"
      ''
        cd ${cfg.dataDir} && exec sudo -u joinmarket ${pkgs.nix-bitcoin.joinmarket}/bin/sendtomany.py --datadir=${cfg.dataDir} "$@"
      '';
      description = ''
        Script to create multiple utxos from one.
      '';
    };
    tumbler = mkOption {
      readOnly = true;
      default = pkgs.writeScriptBin "tumbler.py"
      ''
        cd ${cfg.dataDir} && exec sudo -u joinmarket ${pkgs.nix-bitcoin.joinmarket}/bin/tumbler.py --datadir=${cfg.dataDir} "$@"
      '';
      description = ''
        Script to send bitcoins to many different addresses using
        coinjoin in an attempt to break the link between them.
      '';
    };
    wallet-tool = mkOption {
      readOnly = true;
      default = pkgs.writeScriptBin "wallet-tool.py"
      ''
        cd ${cfg.dataDir} && exec sudo -u joinmarket ${pkgs.nix-bitcoin.joinmarket}/bin/wallet-tool.py --datadir=${cfg.dataDir} "$@"
      '';
      description = ''
        Script to monitor and manage your Joinmarket wallet.
      '';
    };
    # ToDo: Bind joinmarket user to localhost
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
      pkgs.screen
      (hiPrio cfg.wallet-tool)
    ];
    users.users.joinmarket = {
        description = "joinmarket User";
        group = "joinmarket";
        home = cfg.dataDir;
    };
    users.groups.joinmarket = {};

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${config.users.users.joinmarket.name} ${config.users.users.joinmarket.group} - -"
    ];

    # Communication server, needs to run to use any JM script
    systemd.services.joinmarketd = {
      description = "JoinMarket Daemon Service";
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      preStart = ''
        # Create JoinMarket directory structure
        mkdir -m 0770 -p ${cfg.dataDir}/{logs,wallets,cmtdata}
        cp ${configFile} ${cfg.dataDir}/joinmarket.cfg
        chown -R 'joinmarket:joinmarket' '${cfg.dataDir}'
        chmod u=rw,g=,o= ${cfg.dataDir}/joinmarket.cfg
        sed -i "s/rpc_password =/rpc_password = $(cat ${config.nix-bitcoin.secretsDir}/bitcoin-rpcpassword)/g" '${cfg.dataDir}/joinmarket.cfg'
        '';
      serviceConfig = {
        PermissionsStartOnly = "true";
        ExecStart = "${pkgs.nix-bitcoin.joinmarket}/bin/joinmarketd.py";
        User = "joinmarket";
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = "${cfg.dataDir}";
      } // nix-bitcoin-services.defaultHardening
        // nix-bitcoin-services.allowTor;
    };

    systemd.services.joinmarket-yieldgenerator = {
      enable = if cfg.yieldgenerator then true else false;
      description = "JoinMarket Yield Generator Service";
      requires = [ "joinmarketd.service" ];
      after = [ "joinmarketd.service" ];
      preStart = ''
        # Create files (if they don't already exist) with the right ownership/permissions
        touch ${cfg.dataDir}/{joinmarket-wallet-password,yieldgenerator-startscript.sh}
        chown 'joinmarket:joinmarket' ${cfg.dataDir}/{joinmarket-wallet-password,yieldgenerator-startscript.sh}
        chmod u=rw,g=,o= ${cfg.dataDir}/joinmarket-wallet-password
        chmod 700 ${cfg.dataDir}/yieldgenerator-startscript.sh
        # Hacky way to pass wallet password to bot using stdin
        echo -n "cat ${cfg.dataDir}/joinmarket-wallet-password | tr -d '\n' | ${pkgs.nix-bitcoin.joinmarket}/bin/yg-privacyenhanced.py --datadir=${cfg.dataDir} --wallet-password-stdin wallet.jmdat" > ${cfg.dataDir}/yieldgenerator-startscript.sh
        '';
      serviceConfig = {
        WorkingDirectory = "${cfg.dataDir}";
        PermissionsStartOnly = "true";
        ExecStart = "${pkgs.bash}/bin/bash ${cfg.dataDir}/yieldgenerator-startscript.sh";
        User = "joinmarket";
        ReadWritePaths = "${cfg.dataDir}";
      } // nix-bitcoin-services.defaultHardening
        // nix-bitcoin-services.allowTor;
    };
  };
}
