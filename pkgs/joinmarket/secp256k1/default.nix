{ stdenv, fetchFromGitHub, autoreconfHook }:

let inherit (stdenv.lib) optionals; in

stdenv.mkDerivation {
  pname = "secp256k1";

  # I can't find any version numbers, so we're just using the date of the
  # last commit.
  version = "2019-10-11";

  src = fetchFromGitHub {
    owner = "bitcoin-core";
    repo = "secp256k1";
    rev = "0d9540b13ffcd7cd44cc361b8744b93d88aa76ba";
    sha256 = "05zwhv8ffzrfdzqbsb4zm4kjdbjxqy5jh9r83fic0qpk2mkvc2i2";
  };

  nativeBuildInputs = [ autoreconfHook ];

  configureFlags = ["--enable-module-recovery" "--disable-jni" "--enable-experimental" "--enable-module-ecdh" "--enable-benchmark=no" ];

  meta = with stdenv.lib; {
    description = "Optimized C library for EC operations on curve secp256k1";
    longDescription = ''
      Optimized C library for EC operations on curve secp256k1. Part of
      Bitcoin Core. This library is a work in progress and is being used
      to research best practices. Use at your own risk.
    '';
    homepage = "https://github.com/bitcoin-core/secp256k1";
    license = with licenses; [ mit ];
    maintainers = with maintainers; [ nixbitcoin ];
    platforms = with platforms; unix;
  };
}

