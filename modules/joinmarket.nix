{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.joinmarket;
  inherit (config) nix-bitcoin-services;
  secretsDir = config.nix-bitcoin.secretsDir;

  torAddress = builtins.head (builtins.split ":" config.services.tor.client.socksListenAddress);
  configFile = pkgs.writeText "config" ''
    [DAEMON]
    no_daemon = 0
    daemon_port = 27183
    daemon_host = localhost
    use_ssl = false

    [BLOCKCHAIN]
    blockchain_source = bitcoin-rpc
    network = mainnet
    rpc_host = ${builtins.elemAt config.services.bitcoind.rpcbind 0}
    rpc_port = 8332
    rpc_user = ${config.services.bitcoind.rpc.users.privileged.name}
    @@RPC_PASSWORD@@

    [MESSAGING:server1]
    host = darksci3bfoka7tw.onion
    channel = joinmarket-pit
    port = 6697
    usessl = true
    socks5 = true
    socks5_host = ${torAddress}
    socks5_port = 9050

    [MESSAGING:server2]
    host = ncwkrwxpq2ikcngxq3dy2xctuheniggtqeibvgofixpzvrwpa77tozqd.onion
    channel = joinmarket-pit
    port = 6697
    usessl = false
    socks5 = true
    socks5_host = ${torAddress}
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

   # The jm scripts create a 'logs' dir in the working dir,
   # so run them inside dataDir.
   cli = pkgs.runCommand "joinmarket-cli" {} ''
     mkdir -p $out/bin
     jm=${pkgs.nix-bitcoin.joinmarket}/bin
     cd $jm
     for bin in jm-*; do
       {
         echo "#!${pkgs.bash}/bin/bash";
         echo "cd '${cfg.dataDir}' && ${cfg.cliExec} sudo -u ${cfg.user} $jm/$bin --datadir='${cfg.dataDir}' \"\$@\"";
       } > $out/bin/$bin
     done
     chmod -R +x $out/bin
   '';
in {
  options.services.joinmarket = {
    enable = mkEnableOption "JoinMarket";
    yieldgenerator = mkOption {
      type = types.bool;
      default = false;
      description = "Enable the yield generator bot";
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
    cli = mkOption {
      default = cli;
    };
    inherit (nix-bitcoin-services) cliExec;
  };

  config = mkIf cfg.enable (mkMerge [{
    environment.systemPackages = [
      (hiPrio cfg.cli)
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

    # Joinmarket is TOR-only
    services.tor = {
      enable = true;
      client.enable = true;
    };

    systemd.services.joinmarket = {
      description = "Communication server, needs to run to use any JM script";
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        ExecStartPre = nix-bitcoin-services.privileged ''
          install -o '${cfg.user}' -g '${cfg.group}' -m 640 ${configFile} ${cfg.dataDir}/joinmarket.cfg
          sed -i \
             "s|@@RPC_PASSWORD@@|rpc_password = $(cat ${config.nix-bitcoin.secretsDir}/bitcoin-rpcpassword-privileged)|" \
             '${cfg.dataDir}/joinmarket.cfg'
        '';
        ExecStart = "${pkgs.nix-bitcoin.joinmarket}/bin/joinmarketd";
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
      description = "CoinJoin maker bot to gain privacy and passively generate income";
      wantedBy = [ "joinmarket.service" ];
      requires = [ "joinmarket.service" ];
      after = [ "joinmarket.service" ];
      preStart = ''
        jmwalletpassword=$(cat ${secretsDir}/jm-wallet-password)
        echo "echo -n $jmwalletpassword | ${pkgs.nix-bitcoin.joinmarket}/bin/jm-yg-privacyenhanced --datadir=${cfg.dataDir} --wallet-password-stdin wallet.jmdat" > /run/joinmarket-yieldgenerator/startscript.sh
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
