{ version, src, lib, buildPythonPackage, fetchurl, future, txtorcon, pyopenssl, libnacl, joinmarketbase }:

buildPythonPackage rec {
  pname = "joinmarketdaemon";
  inherit version src;

  postUnpack = "sourceRoot=$sourceRoot/jmdaemon";

  propagatedBuildInputs = [ future txtorcon pyopenssl libnacl joinmarketbase ];

  meta = with lib; {
    description = "Daemon for Joinmarket refactored to separate client and backend operations";
    longDescription= ''
      CoinJoin implementation with incentive structure to convince people to take part.
    '';
    homepage = https://github.com/Joinmarket-Org/joinmarket-clientserver;
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.gpl3;
  };
}
