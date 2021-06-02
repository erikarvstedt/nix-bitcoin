{ lib, fetchFromGitHub, python3Packages }:

python3Packages.buildPythonApplication rec {
  pname = "charge-lnd";
  version = "0.1.2";

  src = fetchFromGitHub {
    owner = "accumulator";
    repo = pname;
    rev = "v${version}";
    sha256 = "1m1ic69aj2vlnjlp4ckan8n67r01nfysvq4w6nny32wjkr0zvphr";
  };

  propagatedBuildInputs = with python3Packages; [
    aiorpcx
    colorama
    googleapis_common_protos
    grpcio
    protobuf
    six
    termcolor
  ];

  postInstall = ''
    mkdir -p $out/share/doc
    cp README.md charge.config.example $out/share/doc
  '';

  # there are no tests and running the binary needs config
  doCheck = false;

  meta = with lib; {
    description = "Simple policy-based fee manager for lightning network daemon";
    homepage = "https://github.com/accumulator/charge-lnd";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [ mmilata ];
  };
}
