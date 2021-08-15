{
  description = "A basic nix-bitcoin node";

  inputs.nix-bitcoin.url = "github:fort-nix/nix-bitcoin";

  outputs = { self, nix-bitcoin }: {

    nixosConfigurations.mynode = nix-bitcoin.inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nix-bitcoin.nixosModule
        {
          nix-bitcoin.generateSecrets = true;

          services.bitcoind.enable = true;

          # When using nix-bitcoin as part of a larger NixOS configuration, set the following to enable
          # interactive access to nix-bitcoin features (like bitcoin-cli) for your system's main user
          nix-bitcoin.operator = {
            enable = true;
            name = "main"; # Set this to your system's main user
          };

          # The system's main unprivileged user. This setting is usually part of your
          # existing NixOS configuration.
          users.users.main = {
            isNormalUser = true;
            password = "a";
          };
        }
      ];
    };
  };
}
