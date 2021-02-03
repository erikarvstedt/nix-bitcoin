{ pkgs, buildGoModule, fetchurl, lib }:

buildGoModule rec {
  pname = "lightning-pool";
  version = "0.4.3-alpha";

  src = fetchurl {
    url = "https://github.com/lightninglabs/pool/archive/v${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "0d4c36d119f5fc49cb56b107da46b28a3fd5bf0786c84d812a0c3b49f6f8a781";
  };

  subPackages = [ "cmd/pool" "cmd/poold" ];

  vendorSha256 = "190qy3cz18ipv8ilpqhbaaxfi9j2isxpwhagzzspa3pwcpssrv52";

  meta = with lib; {
    description = ''
      A non-custodial batched uniform clearing-price auction for Lightning Channel Leases (LCL)
    '';
    homepage = "https://github.com/lightninglabs/pool";
    license = lib.licenses.mit;
    maintainers = with maintainers; [ sputn1ck ];
  };
}
