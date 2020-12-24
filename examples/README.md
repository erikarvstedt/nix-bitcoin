Examples
---

The easiest way to try out nix-bitcoin is to use one of the provided examples.

```bash
git clone https://github.com/fort-nix/nix-bitcoin
cd nix-bitcoin/examples/
nix-shell
```

The following example scripts set up a nix-bitcoin node according to [`examples/configuration.nix`](examples/configuration.nix) and then
shut down immediately. They leave no traces (outside of `/nix/store`) on the host system.

- [`./deploy-container.sh`](examples/deploy-container.sh) creates a [NixOS container](https://github.com/erikarvstedt/extra-container).\
  This is the fastest way to set up a node.\
  Requires: [Nix](https://nixos.org/), a systemd-based Linux distro and root privileges

- [`./deploy-qemu-vm.sh`](examples/deploy-qemu-vm.sh) creates a QEMU VM.\
  Requires: [Nix](https://nixos.org/nix/)

- [`./deploy-nixops.sh`](examples/deploy-nixops.sh) creates a VirtualBox VM via [NixOps](https://github.com/NixOS/nixops).\
  NixOps can be used to deploy to various other backends like cloud providers.\
  Requires: [Nix](https://nixos.org/nix/), [VirtualBox](https://www.virtualbox.org)

- [`./deploy-container-minimal.sh`](examples/deploy-container-minimal.sh) creates a
  container defined by [minimal-configuration.nix](examples/minimal-configuration.nix) that
  doesn't use the [secure-node.nix](modules/presets/secure-node.nix) preset.
  Also shows how to use nix-bitcoin in an existing NixOS config.\
  Requires: [Nix](https://nixos.org/), a systemd-based Linux distro and root privileges

Run the examples with option `--interactive` or `-i` to start a shell for interacting with
the node:
```bash
./deploy-qemu-vm.sh -i
```
