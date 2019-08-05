{ pkgs ? import <nixpkgs> {} }:
{
  lightning-charge = pkgs.callPackage ./lightning-charge { };
  nanopos = pkgs.callPackage ./nanopos { };
  spark-wallet = pkgs.callPackage ./spark-wallet { };
  electrs = pkgs.callPackage ./electrs { };
  elementsd = pkgs.callPackage ./elementsd { withGui = false; };
  hwi = pkgs.callPackage ./hwi { };
  pylightning = pkgs.python3Packages.callPackage ./pylightning { };
  liquid-swap = pkgs.python3Packages.callPackage ./liquid-swap { };
  joinmarket = pkgs.callPackage ./joinmarket {
    nixpkgsUnstablePath = (import ./nixpkgs-pinned.nix).nixpkgs-unstable;
  };
  generate-secrets = pkgs.callPackage ./generate-secrets { };
  nixops19_09 = pkgs.callPackage ./nixops { };

  pinned = import ./pinned.nix;
}
