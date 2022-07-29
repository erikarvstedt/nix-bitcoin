# You can run this test via `run-tests.sh -s clightningReplication`

let
  nixpkgs = (import ../pkgs/nixpkgs-pinned.nix).nixpkgs;
in
import "${nixpkgs}/nixos/tests/make-test-python.nix" ({ pkgs, ... }:
let
  keyDir = "${nixpkgs}/nixos/tests/initrd-network-ssh";
  keys = rec {
    server = "${keyDir}/ssh_host_ed25519_key";
    serverPub = "${server}.pub";
  };
  privateKey = pkgs.writeText "private-key" ''
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
in
with pkgs.lib;
{
  name = "clightning-replication";

  nodes = {
    client = { ... }: {
      imports = [ ../modules/modules.nix ];

      nix-bitcoin.generateSecrets = true;
      nix-bitcoin.generateSecretsCmds.clightning-replication-ssh-key = mkForce ''
        install -m 600 ${privateKey} clightning-replication-ssh-key
      '';

      programs.ssh.knownHosts."server".publicKey = readFile keys.serverPub;

      services.clightning = {
        enable = true;
        replication = {
          enable = true;
          encrypt = true;
          sshfs.destination = "nb-replication@server:writable";
        };
      };
      # Disable autostart so we can start it after SSH server is up
      systemd.services.clightning.wantedBy = mkForce [];
    };

    server = { ... }: {
      environment.systemPackages = [ pkgs.gocryptfs ];

      environment.etc."ssh-host-key" = {
        source = keys.server;
        mode = "400";
      };

      services.openssh = {
        enable = true;
        extraConfig = ''
          Match user nb-replication
            ChrootDirectory /var/backup/nb-replication
            AllowTcpForwarding no
            AllowAgentForwarding no
            ForceCommand internal-sftp
            PasswordAuthentication no
            X11Forwarding no
        '';
        hostKeys = mkForce [
          {
            path = "/etc/ssh-host-key";
            type = "ed25519";
          }
        ];
      };

      users.users.nb-replication = {
        isSystemUser = true;
        group = "nb-replication";
        shell = "${pkgs.coreutils}/bin/false";
        openssh.authorizedKeys.keys = [ publicKey ];
      };
      users.groups.nb-replication = {};

      systemd.tmpfiles.rules = [
        # Because this directory is chrooted by sshd, it must only be writable by user/group root
        "d /var/backup/nb-replication 0755 root root - -"
        "d /var/backup/nb-replication/writable 0700 nb-replication - - -"
      ];
    };
  };

  testScript = ''
    if not "is_interactive" in vars():
      start_all()

      server.wait_for_unit("sshd.service")
      client.succeed("systemctl start clightning.service")
      client.wait_for_unit("clightning.service")

      replica_db = "/var/lib/clightning-replication/plaintext/lightningd.sqlite3"
      client.succeed(f"runuser -u clightning -- ls {replica_db}")
      # No other user should be able to read the unencrypted files
      client.fail(f"runuser -u bitcoin -- ls {replica_db}")
      server.succeed("runuser -u nb-replication -- gocryptfs -info /var/backup/nb-replication/writable/lightningd-db/")
  '';
})
