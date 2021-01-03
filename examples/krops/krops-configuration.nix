{ config, pkgs, lib, ... }: {
  nix-bitcoin.secretsDir = "/var/src/secrets";
  environment.variables.NIX_PATH = lib.mkForce "/var/src";
}
