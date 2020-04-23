{ config, pkgs, lib, ... }:

{
  imports = [
    ./bitcoind.nix
    ./clightning.nix
    ./lightning-charge.nix
    ./nanopos.nix
    ./liquid.nix
    ./spark-wallet.nix
    ./electrs.nix
    ./onion-chef.nix
    ./recurring-donations.nix
    ./hardware-wallets.nix
    ./lnd.nix
    ./secrets/secrets.nix
    ./joinmarket.nix
  ];

  disabledModules = [ "services/networking/bitcoind.nix" ];

  options = {
    nix-bitcoin-services = lib.mkOption {
      readOnly = true;
      default = import ./nix-bitcoin-services.nix lib pkgs;
    };
  };

  config = {
    nixpkgs.overlays = [ (self: super: {
      nix-bitcoin = let
        pkgs = import ../pkgs { pkgs = super; };
      in
        pkgs // pkgs.pinned;
    }) ];
  };
}
