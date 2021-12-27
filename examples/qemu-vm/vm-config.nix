{
  # Disable the hardened preset to improve VM performance
  disabledModules = [ <nix-bitcoin/modules/presets/hardened.nix> ];

  config = {
    virtualisation.graphics = false;
    virtualisation.diskSize = 4000;
    services.getty.autologinUser = "root";
    users.users.root = {
      openssh.authorizedKeys.keyFiles = [ ./id-vm.pub ];
    };
  };
}
