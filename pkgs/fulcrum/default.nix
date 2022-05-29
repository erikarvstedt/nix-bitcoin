{ mkDerivation, lib, fetchFromGitHub, pkg-config
, qmake
, qtbase
, rocksdb
, zeromq
}:

mkDerivation rec {
  pname = "fulcrum";
  version = builtins.substring 0 8 src.rev;

  src = fetchFromGitHub {
    owner = "cculianu";
    repo = "Fulcrum";
    rev = "8acdc926fe1ff5913b44bc236449683799299a80";
    sha256 = "sha256-f2bEyp9s07fStMkSHuS28wqmXRq5gJNmQnJXfqCg6t0==";
  };

  nativeBuildInputs = [
    pkg-config
    qmake
  ];

  buildInputs = [
    qtbase
    rocksdb
    zeromq
  ];

  enableParallelBuilding = true;

  meta = with lib; {
    description = "A fast SPV server for BCH and BTC";
    homepage = "https://github.com/cculianu/Fulcrum";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = with maintainers; [ earvstedt ];
  };
}
