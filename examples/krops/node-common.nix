{ extraSources }:
rec {
  pkgs = import <nixpkgs> {};
  nixBitcoinPkgs = import <nix-bitcoin> {};
  source = nixBitcoinPkgs.krops.lib.evalSource [({
      nixpkgs.file = {
        path = toString <nixpkgs>;
        useChecksum = true;
      };
      nix-bitcoin.file = {
        path = toString <nix-bitcoin>;
        useChecksum = true;
        filters = [{
          type = "exclude";
          pattern = ".git";
        }];
      };
      "krops-configuration.nix".file = toString ./krops-configuration.nix;
      secrets.file = toString ../secrets;
  } // extraSources)];
}
