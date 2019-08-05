{ version, src, lib, buildPythonPackage, fetchurl, future, coincurve }:

buildPythonPackage rec {
  pname = "joinmarketbitcoin";
  inherit version src;

  postUnpack = "sourceRoot=$sourceRoot/jmbitcoin";

  propagatedBuildInputs = [ future coincurve ];

  meta = with lib; {
    description = "Bitcoin for Joinmarket refactored to separate client and backend operations";
    longDescription= ''
      CoinJoin implementation with incentive structure to convince people to take part.
    '';
    homepage = https://github.com/Joinmarket-Org/joinmarket-clientserver;
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.gpl3;
  };
}
