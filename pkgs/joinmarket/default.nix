{ stdenv, fetchurl, nixpkgsUnstablePath, python3 }:

let
  version = "0.7.0";
  src = fetchurl {
    url = "https://github.com/JoinMarket-Org/joinmarket-clientserver/archive/v${version}.tar.gz";
    sha256 = "2fd0b40f818182ca8361458bb128f85fb4ae5330ea247a87f4d3d3e2871d4741";
  };

  python = python3.override {
    packageOverrides = self: super: let
      joinmarketPkg = pkg: self.callPackage pkg { inherit version src; };
      unstablePyPkg = pkgName:
        self.callPackage "${nixpkgsUnstablePath}/pkgs/development/python-modules/${pkgName}";
    in {
      joinmarketbase = joinmarketPkg ./jmbase;
      joinmarketclient = joinmarketPkg ./jmclient;
      joinmarketbitcoin = joinmarketPkg ./jmbitcoin;
      joinmarketdaemon = joinmarketPkg ./jmdaemon;

      chromalog = self.callPackage ./chromalog {};
      bencoderpyx = self.callPackage ./bencoderpyx {};
      coincurve = self.callPackage ./coincurve {};
      urldecode = self.callPackage ./urldecode {};
      python-bitcointx = self.callPackage ./python-bitcointx {};
      secp256k1 = self.callPackage ./secp256k1 {};

      txtorcon = unstablePyPkg "txtorcon" {};
    };
  };

  runtimePackages = with python.pkgs; [
    joinmarketbase
    joinmarketclient
    joinmarketbitcoin
    joinmarketdaemon
  ];

  pythonEnv = python.withPackages (_: runtimePackages);
in
stdenv.mkDerivation {
  pname = "joinmarket";
  inherit version src;

  buildInputs = [ pythonEnv ];

  buildCommand = ''
    mkdir -p $src-unpacked
    tar xzf $src --strip 1 -C $src-unpacked
    mkdir -p $out/{bin,src}
    cp $src-unpacked/scripts/add-utxo.py $out/bin
    cp $src-unpacked/scripts/convert_old_wallet.py $out/bin
    cp $src-unpacked/scripts/joinmarketd.py $out/bin
    cp $src-unpacked/scripts/receive-payjoin.py $out/bin
    cp $src-unpacked/scripts/sendpayment.py $out/bin
    cp $src-unpacked/scripts/sendtomany.py $out/bin
    cp $src-unpacked/scripts/tumbler.py $out/bin
    cp $src-unpacked/scripts/wallet-tool.py $out/bin
    cp $src-unpacked/scripts/yg-privacyenhanced.py $out/bin
    chmod +x -R $out/bin
  '';

  passthru = {
      inherit python runtimePackages pythonEnv;
  };
}
