{ pkgs }: with pkgs;

writeScriptBin "nix-bitcoin-release" ''
  export PATH=${lib.makeBinPath [ coreutils gnupg curl jq gnugrep ]}
  . ${./nix-bitcoin-release.sh} ${./key-jonasnick.gpg}
''
