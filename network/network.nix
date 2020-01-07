{
  network.description = "Bitcoin Core node";

  bitcoin-node =
    { config, pkgs, lib, ... }: {
      imports = [ ../configuration.nix ];

      deployment.keys = (import ../modules/secrets/make-secrets.nix {
        inherit config;
        secretsFile = ../secrets/secrets.nix;
      }).activeSecrets;

      # nixops makes the secrets directory accessible only for users with group 'key'.
      # For compatibility with other deployment methods besides nixops, we forego the
      # use of the 'key' group and make the secrets dir world-readable instead.
      # This is safe because all containing files have their specific private
      # permissions set.
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
