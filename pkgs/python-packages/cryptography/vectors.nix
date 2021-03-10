# This file has been copied from nixpkgs rev c7d0dbe094c988209edac801eb2a0cc21aa498d8 (2021-02-22)
# pkgs/development/python-modules/cryptography/vectors.nix

{ buildPythonPackage, fetchPypi, lib, cryptography }:

buildPythonPackage rec {
  pname = "cryptography_vectors";
  version = cryptography.version;
  src = cryptography.src;

  postUnpack = "sourceRoot=$sourceRoot/vectors";

  # No tests included
  doCheck = false;

  meta = with lib; {
    description = "Test vectors for the cryptography package";
    homepage = "https://cryptography.io/en/latest/development/test-vectors/";
    # Source: https://github.com/pyca/cryptography/tree/master/vectors;
    license = with licenses; [ asl20 bsd3 ];
  };
}
