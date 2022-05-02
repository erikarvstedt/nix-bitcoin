{ stdenv, go
, vmTools, runCommand, bash, shadow }:

let
  setup-dirs = stdenv.mkDerivation {
    pname = "setup-dirs";
    version = "0.1";

    nativeBuildInputs = [ go ];

    buildCommand = ''
      mkdir -p $out/bin
      export GOCACHE=$TMPDIR/go-cache
      go build -o $out/bin/setup-dirs ${./setup-dirs.go}
    '';

    passthru = {
      test = vmTest;
    };
  };

  vmTest = vmTools.runInLinuxVM (
    runCommand "setup-dirs-test" {
      buildInputs = [
        setup-dirs
        shadow
        bash
      ];
    } (builtins.readFile ./test.sh)
  );
in
  setup-dirs
