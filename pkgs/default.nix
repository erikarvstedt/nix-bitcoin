let
  nixpkgsPinned = import ./nixpkgs-pinned.nix;
in
# Set default values for use without flakes
{ pkgs ? import <nixpkgs> { config = {}; overlays = []; }
, pkgsUnstable ? import nixpkgsPinned.nixpkgs-unstable {
    inherit (pkgs.stdenv) system;
    config = {};
    overlays = [];
  }
}:
let self = {
  clightning-rest = pkgs.callPackage ./clightning-rest { inherit (self) fetchNodeModules; };
  clboss = pkgs.callPackage ./clboss { };
  clightning-plugins = pkgs.recurseIntoAttrs (import ./clightning-plugins pkgs self.nbPython3Packages);
  joinmarket = pkgs.callPackage ./joinmarket { nbPythonPackageOverrides = import ./python-packages self; };
  lndinit = pkgs.callPackage ./lndinit { };
  liquid-swap = pkgs.python3Packages.callPackage ./liquid-swap { };
  rtl = pkgs.callPackage ./rtl { inherit (self) fetchNodeModules; };
  # The secp256k1 version used by joinmarket
  secp256k1 = pkgs.callPackage ./secp256k1 { };
  spark-wallet = pkgs.callPackage ./spark-wallet { };

  nbPython3Packages = (pkgs.python3.override {
    packageOverrides = import ./python-packages self;
  }).pkgs;

  fetchNodeModules = pkgs.callPackage ./build-support/fetch-node-modules.nix { };

  # Fix clightning build by using python package mistune 0.8.4, which is a
  # strict requirement. This version is affected by CVE-2022-34749, but this
  # is irrelevant in this context.
  #
  # TODO-EXTERNAL:
  # Remove this when the clightning build is fixed upstream.
  clightning = pkgs.callPackage ./clightning-mistune-workaround { inherit (pkgs) clightning; };

  # TODO-EXTERNAL:
  # Remove this when the upstream patch is available in nixpkgs
  lndhub-go = pkgsUnstable.lndhub-go.overrideDerivation (_: {
    patches = [
      (pkgs.fetchpatch {
        # https://github.com/getAlby/lndhub.go/pull/225
        url = "https://github.com/getAlby/lndhub.go/pull/225.patch";
        sha256 = "sha256-yjs+ZHXWhggzd5Zqm+qFKdulFuO/QJQkOmh4i99C9wE=";
      })
    ];
  });

  # Internal pkgs
  netns-exec = pkgs.callPackage ./netns-exec { };
  krops = import ./krops { inherit pkgs; };

  # Deprecated pkgs
  generate-secrets = import ./generate-secrets-deprecated.nix;
  nixops19_09 = pkgs.callPackage ./nixops { };

  pinned = import ./pinned.nix pkgs pkgsUnstable;

  modulesPkgs = self // self.pinned;
}; in self
