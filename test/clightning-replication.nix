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
  privateKeyAppendOnly = pkgs.writeText "id_ed25519" ''
    -----BEGIN OPENSSH PRIVATE KEY-----
    b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
    QyNTUxOQAAACBacZuz1ELGQdhI7PF6dGFafCDlvh8pSEc4cHjkW0QjLwAAAJC9YTxxvWE8
    cQAAAAtzc2gtZWQyNTUxOQAAACBacZuz1ELGQdhI7PF6dGFafCDlvh8pSEc4cHjkW0QjLw
    AAAEAAhV7wTl5dL/lz+PF/d4PnZXuG1Id6L/mFEiGT1tZsuFpxm7PUQsZB2Ejs8Xp0YVp8
    IOW+HylIRzhweORbRCMvAAAADXJzY2h1ZXR6QGt1cnQ=
    -----END OPENSSH PRIVATE KEY-----
  '';
  publicKeyAppendOnly = ''
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFpxm7PUQsZB2Ejs8Xp0YVp8IOW+HylIRzhweORbRCMv root@client
  '';

in {
  name = "clightning-replication";
  meta = with pkgs.lib; {
    maintainers = with maintainers; [ nixbitcoin ];
  };

  nodes = {
    client = { ... }: {
      imports = [ ../modules/modules.nix ];

      nix-bitcoin.generateSecrets = true;

      services.clightning = {
        enable = true;
        replication = {
          enable = true;
          sshfs.destination = "nb-replication@server:writeable";
          encrypt = true;
        };
      };
    };

    server = { ... }: {
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
        isNormalUser = true;
        shell = "${pkgs.coreutils}/bin/false";
        group = "nb-replication";
        extraGroups = [ "sftponly" ];
      };
      users.groups.nb-replication = {};

      systemd.tmpfiles.rules = [
        "d '/var/backup/nb-replication' 0755 root root - -"
        "d '/var/backup/nb-replication/writeable' 0700 <user> sftponly - -"
      ];
    };
  };

  testScript = ''
    start_all()
    client.succeed(
        "cp ${privateKey} /root/id_ed25519"
    )
    client.succeed("chmod 0600 /root/id_ed25519")
    client.succeed(
        "cp ${privateKeyAppendOnly} /root/id_ed25519.appendOnly"
    )
    client.succeed("chmod 0600 /root/id_ed25519.appendOnly")
  '';
})
