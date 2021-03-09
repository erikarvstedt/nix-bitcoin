nbPkgs:
self:
let
  inherit (self) callPackage;

  joinmarketPkg = pkg: callPackage pkg { inherit (nbPkgs.joinmarket) version src; };
  clightningPkg = pkg: callPackage pkg { inherit (nbPkgs.pinned) clightning; };

  # nixpkgs as of 2021-02-22
  nixpkgsCryptography = builtins.fetchTarball {
    url = "https://github.com/nixos/nixpkgs/archive/c7d0dbe094c988209edac801eb2a0cc21aa498d8.tar.gz";
    sha256 = "1rwjfjwwaic56n778fvrmv1s1vzw565gqywrpqv72zrrzmavhyrx";
  };
in {
  bencoderpyx = callPackage ./bencoderpyx {};
  coincurve = callPackage ./coincurve {};
  python-bitcointx = callPackage ./python-bitcointx { inherit (nbPkgs) secp256k1; };
  urldecode = callPackage ./urldecode {};
  chromalog = callPackage ./chromalog {};
  txzmq = callPackage ./txzmq {};

  # Cryptography version 3.3.2, required by joinmarketdaemon
  cryptography = callPackage "${nixpkgsCryptography}/pkgs/development/python-modules/cryptography" {};
  cryptography_vectors = callPackage "${nixpkgsCryptography}/pkgs/development/python-modules/cryptography/vectors.nix" {};

  joinmarketbase = joinmarketPkg ./jmbase;
  joinmarketclient = joinmarketPkg ./jmclient;
  joinmarketbitcoin = joinmarketPkg ./jmbitcoin;
  joinmarketdaemon = joinmarketPkg ./jmdaemon;

  pyln-client = clightningPkg ./pyln-client;
  pyln-proto = clightningPkg ./pyln-proto;
  pylightning = clightningPkg ./pylightning;
}
