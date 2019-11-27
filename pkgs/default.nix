{ pkgs ? import <nixpkgs> {} }:
{
  # 'lib', 'modules' and 'overlays' are special, see
  # https://github.com/nix-community/NUR for more.
  modules = import ./modules; # NixOS modules

  nodeinfo = pkgs.callPackage ./nodeinfo { };
  banlist = pkgs.callPackage ./banlist { };
  lightning-charge = pkgs.callPackage ./lightning-charge { };
  nanopos = pkgs.callPackage ./nanopos { };
  spark-wallet = pkgs.callPackage ./spark-wallet { };
  electrs = (pkgs.callPackage ./electrs { }).rootCrate.build;
  elementsd = pkgs.callPackage ./elementsd { withGui = false; };
  hwi = pkgs.callPackage ./hwi { };
  pylightning = pkgs.python3Packages.callPackage ./pylightning { };
  liquid-swap = pkgs.python3Packages.callPackage ./liquid-swap { };
  generate-secrets = pkgs.callPackage ./generate-secrets { };
}
