import "${(import ../pkgs/nixpkgs-pinned.nix).nixpkgs}/nixos/tests/make-test-python.nix" ({ pkgs, ... }:
let
  privateKey = pkgs.writeText "id_ed25519" ''
    -----BEGIN OPENSSH PRIVATE KEY-----
    b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
    QyNTUxOQAAACBx8UB04Q6Q/fwDFjakHq904PYFzG9pU2TJ9KXpaPMcrwAAAJB+cF5HfnBe
    RwAAAAtzc2gtZWQyNTUxOQAAACBx8UB04Q6Q/fwDFjakHq904PYFzG9pU2TJ9KXpaPMcrw
    AAAEBN75NsJZSpt63faCuaD75Unko0JjlSDxMhYHAPJk2/xXHxQHThDpD9/AMWNqQer3Tg
    9gXMb2lTZMn0pelo8xyvAAAADXJzY2h1ZXR6QGt1cnQ=
    -----END OPENSSH PRIVATE KEY-----
  '';
  publicKey = ''
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHHxQHThDpD9/AMWNqQer3Tg9gXMb2lTZMn0pelo8xyv root@client
  '';

in {
  name = "clightning-replication";
  meta = with pkgs.lib; {
    maintainers = with maintainers; [ nixbitcoin ];
  };

  nodes = {
    client = { ... }: {
      imports = [ ../modules/modules.nix ];

      nix-bitcoin.secretsDir = "/secrets";
      nix-bitcoin.generateSecrets = true;

      services.clightning = {
        enable = true;
        replication = {
          enable = true;
          sshfs = {
            destination = "nb-replication@server:writeable";
            sshOptions = [ "StrictHostKeyChecking=no" ];
          };
          encrypt = true;
        };
      };
      # Disable autostart so we can start it after ssh server is up
      systemd.services.clightning.wantedBy = pkgs.lib.mkForce [];
    };

    server = { ... }: {
      environment.systemPackages = [ pkgs.gocryptfs ];

      services.openssh = {
        enable = true;
        passwordAuthentication = false;
        kbdInteractiveAuthentication = false;
        extraConfig = ''
          Match group sftponly
            ChrootDirectory /var/backup/%u
            X11Forwarding no
            AllowTcpForwarding no
            AllowAgentForwarding no
            ForceCommand internal-sftp
        '';
      };

      users.groups.sftponly = {};
      users.users.nb-replication = {
        isSystemUser = true;
        shell = "${pkgs.coreutils}/bin/false";
        group = "nb-replication";
        extraGroups = [ "sftponly" ];
        openssh.authorizedKeys.keys = [ "${publicKey}" ];
      };
      users.groups.nb-replication = {};

      systemd.tmpfiles.rules = [
        "d '/var/backup/nb-replication' 0755 root root - -"
        "d '/var/backup/nb-replication/writeable' 0700 nb-replication sftponly - -"
      ];
    };
  };

  testScript = ''
    if not "is_interactive" in vars():
      start_all()
      client.succeed(
          "cp ${privateKey} /secrets/clightning-replication-ssh-key"
      )
      client.succeed("chmod 0600 /secrets/clightning-replication-ssh-key")

      server.wait_for_unit("sshd.service")
      client.succeed("systemctl start clightning.service")
      client.wait_for_unit("clightning.service")

      replica_db = "/var/lib/clightning-replication/plaintext/lightningd.sqlite3"
      client.succeed(f"runuser -u clightning -- ls {replica_db}")
      # No other user should be able to read the unencrypted files
      client.fail(f"runuser -u bitcoin -- ls {replica_db}")
      server.succeed("runuser -u nb-replication -- gocryptfs -info /var/backup/nb-replication/writeable/lightningd-db/")
  '';
})
