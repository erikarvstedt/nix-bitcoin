{ lib, buildPythonPackage, fetchurl, secp256k1 }:

buildPythonPackage rec {
  pname = "python-bitcointx";
  version = "1.1.1";

  src = fetchurl {
    urls = [
            "https://github.com/Simplexum/${pname}/archive/${pname}-v${version}.tar.gz"
           ];
    sha256 = "35edd694473517508367338888633954eaa91b2622b3caada8fd3030ddcacba2";
  };

  propagatedBuildInputs = [ secp256k1 ];

  preConfigure = ''
    cp -r ${secp256k1.src} libsecp256k1
    touch libsecp256k1/autogen.sh
    export INCLUDE_DIR=${secp256k1}/include
    export LIB_DIR=${secp256k1}/lib
  '';

  meta = with lib; {
    description = ''
      python-bitcointx is a python3 library providing an easy interface to the
      Bitcoin data structures
    '';
    homepage = https://github.com/Simplexum/python-bitcointx;
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.gpl3;
  };
}
