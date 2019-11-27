{
  network.description = "Bitcoin Core node";

  bitcoin-node =
    { config, pkgs, lib, ... }: {
      imports = [ ../configuration.nix ];

      deployment.keys = (import ../modules/secrets/make-secrets.nix {
        inherit config;
        secretsFile = ../secrets/secrets.nix;
      }).activeSecrets;

      systemd.services.allowSecretsDirAccess = {
        requires = [ "keys.target" ];
        after = [ "keys.target" ];
        script = "chmod o+x /secrets";
        serviceConfig.Type = "oneshot";
      };

      systemd.targets.nix-bitcoin-secrets = {
        requires = [ "allowSecretsDirAccess.service" ];
        after = [ "allowSecretsDirAccess.service" ];
      };
    };
}
