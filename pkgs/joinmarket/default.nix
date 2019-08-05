{ stdenv, fetchurl, nixpkgsUnstablePath, python3 }:

let
  version = "0.6.2";
  src = fetchurl {
    url = "https://github.com/JoinMarket-Org/joinmarket-clientserver/archive/v${version}.tar.gz";
    sha256 = "99b8ac502288a9532d172e15b8f5dd3a2795549a782cedc5719ebe52c1b014c5"; # GPG verified
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

      txtorcon = unstablePyPkg "txtorcon" {};
      twisted = (unstablePyPkg "twisted" {}).overrideAttrs (old: rec {
        # Joinmarket requires this specific version
        version = "19.7.0";
        src = self.fetchPypi {
          inherit (old) pname;
          inherit version;
          extension = "tar.bz2";
          sha256 = "d5db93026568f60cacdc0615fcd21d46f694a6bfad0ef3ff53cde2b4bb85a39d";
        };
      });
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
    # These scripts missing a shebang
    sed -i '1 i #!/usr/bin/env python' $out/bin/joinmarketd.py
    sed -i '1 i #!/usr/bin/env python' $out/bin/wallet-tool.py
    chmod +x -R $out/bin
    patchShebangs $out/bin
  '';

  passthru = {
      inherit python runtimePackages pythonEnv;
  };
}
