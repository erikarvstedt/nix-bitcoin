{ lib
, stdenv
, fetchFromGitHub
, autoconf
, automake
, autogen
, gettext
, libtool
, pkg-config
, unzip
, which
, gmp
, libsodium
, python3
, sqlite
, zlib
}:
let
  py3 = python3.withPackages (p: [ p.Mako p.mrkd ]);
in
stdenv.mkDerivation rec {
  pname = "clightning";
  version = "0.10.2";

  src = fetchFromGitHub {
    owner = "ElementsProject";
    repo = "lightning";
    rev = "a2946836751992678f31e0c1a384d7fb4146a017";
    sha256 = "sha256-zb0pnC3kurEnS+W8ybD7itMckrUh9V2jVBPEAVrFqfM=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [ autogen autoconf automake gettext libtool pkg-config py3 unzip which ];

  buildInputs = [ gmp libsodium sqlite zlib ];

  postPatch = ''
    patchShebangs \
      tools/generate-wire.py \
      tools/update-mocks.sh \
      tools/mockup.sh \
      devtools/sql-rewrite.py
  '';

  configureFlags = [ "--disable-developer" "--disable-valgrind" ];

  makeFlags = [ "VERSION=v${version}" ];

  enableParallelBuilding = true;

  meta = with lib; {
    description = "A Bitcoin Lightning Network implementation in C";
    longDescription = ''
      c-lightning is a standard compliant implementation of the Lightning
      Network protocol. The Lightning Network is a scalability solution for
      Bitcoin, enabling secure and instant transfer of funds between any two
      parties for any amount.
    '';
    homepage = "https://github.com/ElementsProject/lightning";
    maintainers = with maintainers; [ jb55 prusnak ];
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
