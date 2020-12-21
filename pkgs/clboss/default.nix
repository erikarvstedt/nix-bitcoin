{ stdenv, pkgs, fetchurl, pkgconfig, curl, dnsutils, libev, sqlite }:

let
  curlWithGnuTls = curl.override { gnutlsSupport = true; sslSupport = false; };

in

with stdenv.lib;
stdenv.mkDerivation rec {
  pname = "clboss";
  version = "0.10";

  src = fetchurl {
    url = "https://github.com/ZmnSCPxj/clboss/releases/download/v${version}/clboss-${version}.tar.gz";
    sha256 = "1bmlpfhsjs046qx2ikln15rj4kal32752zs1s5yjklsq9xwnbciz";
  };

  enableParallelBuilding = true;

  nativeBuildInputs = [ pkgconfig libev curlWithGnuTls sqlite ];

  propogatedBuildInputs = [ dnsutils ];

  meta = {
    description = "Automated C-Lightning Node Manager";
    homepage = "https://github.com/ZmnSCPxj/clboss";
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
