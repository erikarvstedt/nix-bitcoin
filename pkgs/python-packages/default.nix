nbPkgs:
self:
let
  inherit (self) callPackage;

  joinmarketPkg = pkg: callPackage pkg { inherit (nbPkgs.joinmarket) version src; };
  clightningPkg = pkg: callPackage pkg { inherit (nbPkgs.pinned) clightning; };

  unstable = (import ../nixpkgs-pinned.nix).nixpkgs-unstable;
in {
  bencoderpyx = callPackage ./bencoderpyx {};
  coincurve = callPackage ./coincurve {};
  python-bitcointx = callPackage ./python-bitcointx { inherit (nbPkgs) secp256k1; };
  urldecode = callPackage ./urldecode {};
  chromalog = callPackage ./chromalog {};
  txzmq = callPackage ./txzmq {};

  # Cryptography from nixpkgs-unstable (v3.3.2)
  # v3.3.2 is pinned by joinmarket for reasons not relevant to this system.
  # TODO: Add `patchPhase` removing the Cryptography version pin from
  # `jmdaemon/setup.py` when updating nixpkgs-unstable.
  cryptography = callPackage "${unstable}/pkgs/development/python-modules/cryptography" {};
  cryptography_vectors = callPackage "${unstable}/pkgs/development/python-modules/cryptography/vectors.nix" {};

  joinmarketbase = joinmarketPkg ./jmbase;
  joinmarketclient = joinmarketPkg ./jmclient;
  joinmarketbitcoin = joinmarketPkg ./jmbitcoin;
  joinmarketdaemon = joinmarketPkg ./jmdaemon;

  pyln-client = clightningPkg ./pyln-client;
  pyln-proto = clightningPkg ./pyln-proto;
  pylightning = clightningPkg ./pylightning;
}
