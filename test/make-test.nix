testArgs:

let
  pkgs = import <nixpkgs> { config = {}; overlays = []; };

  pkgs19_09 = import (pkgs.fetchzip {
    url = "https://github.com/NixOS/nixpkgs-channels/archive/a7ceb2536ab11973c59750c4c48994e3064a75fa.tar.gz";
    sha256 = "0hka65f31njqpq7i07l22z5rs7lkdfcl4pbqlmlsvnysb74ynyg1";
  }) { config = {}; overlays = []; };

  test = (import "${pkgs.path}/nixos/tests/make-test-python.nix") testArgs;

  fixedTest = { system ? builtins.currentSystem, ... }@args:
    let
       pkgsFixed = pkgs // {
         # Fix the black Python code formatter that's used in the test to allow the test
         # script to have longer lines. The default width of 88 chars is too restrictive for
         # our script.
         python3Packages = pkgs.python3Packages // {
           black = pkgs.writeScriptBin "black" ''
             fileToCheck=''${@:$#}
             [[ $fileToCheck = *test-script ]] && extraArgs='--line-length 100'
             exec ${pkgs.python3Packages.black}/bin/black $extraArgs "$@"
           '';
         };
       };
    in
      test (args // { pkgs = pkgsFixed; });
in
  fixedTest
