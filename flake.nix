{
  description = ''
    A collection of Nix packages and NixOS modules for easily
    installing full-featured Bitcoin nodes with an emphasis on security.
  '';

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.05";
    nixpkgsUnstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixpkgsUnstable, flake-utils }:
    let
      supportedSystems = [ "x86_64-linux" "i686-linux" "aarch64-linux" ];
    in
    rec {
      mkNbPkgs = {
        system
        , pkgs ? import nixpkgs { inherit system; }
        , pkgsUnstable ? import nixpkgsUnstable { inherit system; }
      }:
        import ./pkgs { inherit pkgs pkgsUnstable; };

      overlay = final: prev: let
        nbPkgs = mkNbPkgs { inherit (final) system; pkgs = final; };
      in removeAttrs nbPkgs [ "pinned" "nixops19_09" "krops" ];

      nixosModule = self.nixosModules.withSystemPkgs;

      nixosModules = {
        # Uses the default system pkgs for nix-bitcoin.pkgs
        withSystemPkgs =  { config, pkgs, ... }: {
          imports = [ ./modules/modules.nix ];
          nix-bitcoin.pkgs = (mkNbPkgs { inherit (config.nixpkgs) system; inherit pkgs; }).modulesPkgs;
        };

        # Uses the nixpkgs version locked by this flake for nix-bitcoin.pkgs.
        # More stable, but slightly slower to evaluate and needs more space if the
        # locked and the system nixpkgs versions differ.
        withLockedPkgs =  { config, ... }: {
          imports = [ ./modules/modules.nix ];
          nix-bitcoin.pkgs = (mkNbPkgs { inherit (config.nixpkgs) system; }).modulesPkgs;
        };
      };

      defaultTemplate = {
        description = "Basic node template";
        path = ./examples/flakes;
      };

    } // (flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = import nixpkgs { inherit system; };

        mkVMScript = vm: pkgs.writers.writeBash "run-vm" ''
          set -euo pipefail
          export TMPDIR=$(mktemp -d /tmp/nix-bitcoin-vm.XXX)
          export NIX_DISK_IMAGE=$TMPDIR/nixos.qcow2
          trap "rm -rf $TMPDIR" EXIT
          QEMU_OPTS="-smp $(nproc) -m 2000" ${vm}/bin/run-*-vm
        '';
      in rec {
        nbPkgs = self.mkNbPkgs { inherit system pkgs; };

        packages = flake-utils.lib.flattenTree (removeAttrs nbPkgs [
          "pinned" "modulesPkgs" "nixops19_09" "krops"
        ]) // {
          runVM = mkVMScript packages.vm;

          vm = let
            # Add an alias so that this snippet can be copied to other flakes
            nix-bitcoin = self;
          in
            (import "${nixpkgs}/nixos" {
              inherit system;
              configuration = {
                imports = [
                  nix-bitcoin.nixosModule
                  "${nix-bitcoin}/modules/presets/secure-node.nix"
                ];

                nix-bitcoin.generateSecrets = true;
                services.clightning.enable = true;
                # For faster startup in offline VMs
                services.clightning.extraConfig = "disable-dns";

                nixpkgs.pkgs = pkgs;
                virtualisation.graphics = false;
                services.getty.autologinUser = "root";
                nix.nixPath = [ "nixpkgs=${nixpkgs}" ];
              };
            }).vm;
        };

        defaultApp = apps.vm;

        apps = {
          # Run a basic nix-bitcoin node in a VM
          vm = {
            type = "app";
            program = toString packages.runVM;
          };
        };
      }
    ));
}
