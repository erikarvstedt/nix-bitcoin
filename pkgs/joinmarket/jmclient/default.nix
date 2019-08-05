{ version, src, lib, buildPythonPackage, fetchurl, future, configparser, joinmarketbase, mnemonic, argon2_cffi, bencoderpyx, pyaes, joinmarketbitcoin }:

buildPythonPackage rec {
  pname = "joinmarketclient";
  inherit version src;

  postUnpack = "sourceRoot=$sourceRoot/jmclient";

  checkInputs = [ joinmarketbitcoin ];

  # configparser may need to be compiled with python_version<"3.2"
  propagatedBuildInputs = [ future configparser joinmarketbase mnemonic argon2_cffi bencoderpyx pyaes ];

  meta = with lib; {
    description = "Client for Joinmarket refactored to separate client and backend operations";
    longDescription= ''
      CoinJoin implementation with incentive structure to convince people to take part.
    '';
    homepage = https://github.com/Joinmarket-Org/joinmarket-clientserver;
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.gpl3;
  };
}
