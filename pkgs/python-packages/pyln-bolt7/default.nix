{ buildPythonPackage, clightning, pyln-proto }:

buildPythonPackage rec {
  pname = "pyln-bolt7";
  version = "1.0.2.186";

  inherit (clightning) src;

  propagatedBuildInputs = [ pyln-proto ];

  postUnpack = "sourceRoot=$sourceRoot/contrib/pyln-spec/bolt7";
  postPatch = ''
    sed -i '
      s|pyln.proto|pyln-proto|
    ' requirements.txt
  '';
}
