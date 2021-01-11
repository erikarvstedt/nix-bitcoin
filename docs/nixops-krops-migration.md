# Tutorial: Moving from a NixOps to a Krops deployment

1. Add a new ssh key to your nix-bitcoin node

   Krops doesn't automatically generate ssh keys like NixOps, instead you add your own.

   If you don't have a ssh key yet

   ```
   ssh-keygen -t ed25519 -f ~/.ssh/bitcoin-node
   ```

   Edit `configuration.nix`

   ```
   users.users.root = {
     openssh.authorizedKeys.keys = [
       "<contents of ~/.ssh/bitcoin-node.pub or existing .pub key file>"
     ];
   };
   ```

   Deploy new key

   ```
   nixops deploy -d bitcoin-node
   ```

2. Update your nix-bitcoin, depending on your setup either with `fetch-release` or `git`. Make sure you are at least on `v0.0.31`.

3. Pull the newest nix-bitcoin source

    ```
    cd ~/nix-bitcoin
    git pull
    ```

4. Pull the new `krops` folder and `shell.nix` into your deployment folder

    ```
    cd <deployment directory, for example `~/nix-bitcoin-node`>
    cp -r ~/nix-bitcoin/examples/{krops,shell.nix} .
    ```

5. Edit your ssh config

    ```
    nano ~/.ssh/config
    ```

    and add the node with an entry similar to the following (make sure to fix `Hostname` and `IdentityFile`):

    ```
    Host bitcoin-node
        # FIXME
        Hostname NODE_IP_ADDRESS_OR_HOST_NAME_HERE
        User root
        PubkeyAuthentication yes
        # FIXME
        IdentityFile <ssh key from step 1 or path to existing key>
        AddKeysToAgent yes
    ```

6. Make sure you are in the deployment directory and edit `krops/node.nix`

    ```
    nano krops/node.nix
    ```

    Locate the `FIXME` and set the target to the name of the ssh config entry created earlier, i.e. `bitcoin-node`.

7. Enable krops in your `configuration.nix`

    ```
    nano configuration.nix
    ```

    Add the following line

    ```
    ./krops-configuration.nix
    ```

    to `imports` like so

    ```
    imports = [
      <nix-bitcoin/modules/presets/secure-node.nix>

      # FIXME: The hardened kernel profile improves security but
      # decreases performance by ~50%.
      # Turn it off when not needed.
      <nix-bitcoin/modules/presets/hardened.nix>

      # FIXME: Uncomment next line to import your hardware configuration. If so,
      # add the hardware configuration file to the same directory as this file.
      ./hardware-configuration.nix

      # FIXME: Uncomment next line to import settings specific to deployments with
      # krops.
      ./krops-configuration.nix
    ];
    ```

7. Enter environment

    ```
    nix-shell
    ```

8. Deploy with krops in nix-shell

    ```
    krops-deploy
    ```

9. You can now access bitcoin-node through ssh in nix-shell with

    ```
    ssh operator@bitcoin-node
    ```
