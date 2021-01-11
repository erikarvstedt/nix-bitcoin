{ config, pkgs, lib, ... }: {
  imports = [
    <nix-bitcoin/modules/deployment/krops.nix>
  ];
  krops.secrets.files = builtins.mapAttrs (n: v: {
    source-path = "/var/src/secrets/${n}";
    path = "${config.nix-bitcoin.secretsDir}/${n}";
    inherit (v) user group permissions;
  }) config.nix-bitcoin.secrets;
  environment.variables.NIX_PATH = lib.mkForce "/var/src";
}
