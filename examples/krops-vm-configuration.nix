{ lib, ... }: {
  imports = [
    ./krops-configuration.nix
    <qemu-vm/vm-config.nix>
    <nixpkgs/nixos/modules/virtualisation/qemu-vm.nix>
  ];
}