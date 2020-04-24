Updating
---
In your deployment directory, enter the nix shell with `nix-shell` and run

```
fetch-release > nix-bitcoin-release.nix
```

Nodeinfo
---
Run `nodeinfo` to see your onion addresses for the webindex, spark, etc. if they are enabled.

Connect to spark-wallet
---
### Requirements
* Android phone
* [Orbot](https://guardianproject.info/apps/orbot/) installed from [F-Droid](https://guardianproject.info/fdroid) (recommended) or [Google Play](https://play.google.com/store/apps/details?id=org.torproject.android&hl=en)
* [Spark-wallet](https://github.com/shesek/spark-wallet) installed from [direct download](https://github.com/shesek/spark-wallet/releases) or [Google Play](https://play.google.com/store/apps/details?id=com.spark.wallet)

1. Enable spark-wallet in `configuration.nix`

    Change
    ```
    # services.spark-wallet.enable = true;
    ```
    to
    ```
    services.spark-wallet.enable = true;
    ```

2. Deploy new `configuration.nix`

    ```
    nixops deploy -d bitcoin-node
    ```

3. Enable Orbot VPN for spark-wallet

    ```
    Open Orbot app
    Turn on "VPN Mode"
    Select Gear icon under "Tor-Enabled Apps"
    Toggle checkbox under Spark icon
    ```

4. Get the onion address, access key and QR access code for the spark wallet android app

    ```
    journalctl -eu spark-wallet
    ```
    Note: The qr code might have issues scanning if you have a light terminal theme. Try setting it to dark or highlightning the entire output to invert the colors.

5. Connect to spark-wallet android app

    ```
    Server Settings
    Scan QR
    Done
    ```

Connect to electrs
---
### Requirements Android
* Android phone
* [Orbot](https://guardianproject.info/apps/orbot/) installed from [F-Droid](https://guardianproject.info/fdroid) (recommended) or [Google Play](https://play.google.com/store/apps/details?id=org.torproject.android&hl=en)
* [Electrum mobile app](https://electrum.org/#home) installed from [direct download](https://electrum.org/#download) or [Google Play](https://play.google.com/store/apps/details?id=org.electrum.electrum)

### Requirements Desktop
* [Tor](https://www.torproject.org/) installed from [source](https://www.torproject.org/docs/tor-doc-unix.html.en) or [repository](https://www.torproject.org/docs/debian.html.en)
* [Electrum](https://electrum.org/#download) installed

1. Enable electrs in `configuration.nix`

    Change
    ```
    # services.electrs.enable = true;
    ```
    to
    ```
    services.electrs.enable = true;
    ```

2. Deploy new `configuration.nix`

    ```
    nixops deploy -d bitcoin-node
    ```

3. Get electrs onion address

    ```
    nodeinfo | grep 'ELECTRS_ONION'
    ```

4. Connect to electrs

    On electrum wallet laptop
    ```
    electrum --oneserver --server=<ELECTRS_ONION>:50002:s --proxy=socks5:localhost:9050
    ```

    On electrum android phone
    ```
    Three dots in the upper-right-hand corner
    Network
    Proxy mode: socks5, Host: 127.0.0.1, Port: 9050
    Ok
    Server
    Host: <ELECTRS_ONION>, Port: 50002
    Ok
    Auto-connect: OFF
    One-server mode: ON
    ```

Connect to nix-bitcoin node through ssh Tor Hidden Service
---
1. Run `nodeinfo` on your nix-bitcoin node and note the `SSHD_ONION`

    ```
    nixops ssh operator@bitcoin-node
    nodeinfo | grep 'SSHD_ONION'
    ```

2. Create a SSH key

    ```
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
    ```

3. Place the ed25519 key's fingerprint in the `configuration.nix` `openssh.authorizedKeys.keys` field like so

    ```
    # FIXME: Add your SSH pubkey
    services.openssh.enable = true;
    users.users.root = {
      openssh.authorizedKeys.keys = [ "[contents of ~/.ssh/id_ed25519.pub]" ];
    };
    ```

4. Connect to your nix-bitcoin node's ssh Tor Hidden Service, forwarding a local port to the nix-bitcoin node's ssh server

    ```
    ssh -i ~/.ssh/id_ed25519 -L [random port of your choosing]:localhost:22 root@[your SSHD_ONION]
    ```

5. Edit your `network-nixos.nix` to look like this

    ```
    {
      bitcoin-node =
        { config, pkgs, ... }:
        { deployment.targetHost = "127.0.0.1";
        deployment.targetPort = [random port of your choosing];
        };
    }
    ```

6. Now you can run `nixops deploy -d bitcoin-node` and it will connect through the ssh tunnel you established in step iv. This also allows you to do more complex ssh setups that `nixops ssh` doesn't support. An example would be authenticating with [Trezor's ssh agent](https://github.com/romanz/trezor-agent), which provides extra security.

Initialize a Trezor for Bitcoin Core's Hardware Wallet Interface
---

1. Enable Trezor in `configuration.nix`

    Change
    ```
    # services.hardware-wallets.trezor = true;
    ```
    to
    ```
    services.hardware-wallets.trezor = true;
    ```

2. Deploy new `configuration.nix`

    ```
    nixops deploy -d bitcoin-node
    ```

3. Check that your nix-bitcoin node recognizes your Trezor

    ```
    nixops ssh operator@bitcoin-node
    lsusb
    ```
    Should show something relating to your Trezor

4. If your Trezor has outdated firmware or is not yet initialized: Start your Trezor in bootloader mode

    Trezor v1
    ```
    Plug in your Trezor with both buttons depressed
    ```

    Trezor v2
    ```
    Start swiping your finger across your Trezor's touchscreen and plug in the USB cable when your finger is halfway through
    ```

5. If your Trezor's firmware is outdated: Update your Trezor's firmware

    ```
    trezorctl firmware-update
    ```
    Follow the on-screen instructions

    **Caution: This command _will_ wipe your Trezor. If you already store Bitcoin on it, only do this with the recovery seed nearby.**

6. If your Trezor is not yet initialized: Set up your Trezor

    ```
    trezorctl reset-device -p
    ```
    Follow the on-screen instructions

7. Find your Trezor

    ```
    hwi enumerate
    hwi -t trezor -d <path from previous command> promptpin
    hwi -t trezor -d <path> sendpin <number positions for the PIN as displayed on your device's screen>
    hwi enumerate
    ```

8. Follow Bitcoin Core's instructions on [Using Bitcoin Core with Hardware Wallets](https://github.com/bitcoin-core/HWI/blob/master/docs/bitcoin-core-usage.md) to use your Trezor with `bitcoin-cli` on your nix-bitcoin node

JoinMarket
---

## Initialize JoinMarket Wallet

1. Enable JoinMarket

   Change
   ```
   # services.joinmarket.enable = true;
   ```
   to
   ```
   services.joinmarket.enable = true;
   ```
   in your `configuration.nix`

2. Deploy to your node, for example

   ```console
   $ nix-shell
   $ nixops deploy
   ```

3. SSH into your nix-bitcoin node

   ```console
   $ nixops ssh operator@bitcoin-node
   ```

4. Generate wallet

    ```console
    $ wallet-tool.py generate
    ```
    Follow the on-screen instructions and write down your seed. Leave the wallet name as wallet.jmdat!

5. Send funds to JoinMarket wallet

   Show addresses

   ```console
   $ wallet-tool.py wallet.jmdat
   ```

   ```
   JM wallet
   mixdepth	0	xpub6Crt4fcfpnrNxW45MzuV626z4fjddsuFGwRn1DXdpwnDkBMR12GKdBzW8euDqLSqRRv2eZmcJy8FSQLWEosC6wFZAZEv3FJMtvZ7W1CkQDi
   external addresses	m/49'/0'/0'/0	xpub6FQFAscJgwd8MXCcAT8A1hgx9vigrgVoXVNTAKHj2aK3NR2Zf1CbFNXD8G8X9dspGXLY9eiEzBWaypr24owJ8r1aTKgMbUZoTnQ36bBwQB3
   m/49'/0'/0'/0/0     	35SrGbUt9FpfA6xqKMpNaiTNyeuXagBi7Y	0.00000000	new
   m/49'/0'/0'/0/1     	39hc2xfA6i9kWZdXMwH4Pd9dWUvDKocGd3	0.00000000	new
   m/49'/0'/0'/0/2     	371MJcjFG4cEpz8RVdYb1L8PkA9tZYySGZ	0.00000000	new
   m/49'/0'/0'/0/3     	39eTy635wLCyBbphUTNnSB2V9LnvgdndNo	0.00000000	new
   m/49'/0'/0'/0/4     	33T8eNr54maWNZYQjoZwpLA2HGk7RJaLVb	0.00000000	new
   m/49'/0'/0'/0/5     	35kJoTSxHtQbKUg2jvjDVqcY9iXoH2cTqD	0.00000000	new
   Balance:	0.00000000
   internal addresses	m/49'/0'/0'/1
   Balance:	0.00000000
   Balance for mixdepth 0:	0.00000000
   mixdepth	1	xpub6Crt4fcfpnrP2GZnVuT1qi9aw9cpCuXcnGEjAKhaoWAHq5M4pWX64DNio3XHirY5uTCZCi6vTmaLjU5YQXbVsTjyEdCE2zn3S2fzBNFjxs8
   external addresses	m/49'/0'/1'/0	xpub6E2EnYy6yBXvE9U1nR5sSH58YiwbsKFZzaMkgMY5jrt2XFe4D5HVwikeTWyjuoczjQhJNezkwxrKAbUPMEDYHmbiaaiEAeXcL1yAcEAqtd7
   m/49'/0'/1'/0/0     	3DdhEr9GCoMDVRLNGAwi9rb8F4HQX8newY	0.00000000	new
   m/49'/0'/1'/0/1     	342XPkCQYzZkdUaB9TGPfVhf1iX55yE4gH	0.00000000	new
   m/49'/0'/1'/0/2     	33RaQJTn1P8KNUvNnPRFM19zHjPhzuyCqc	0.00000000	new
   m/49'/0'/1'/0/3     	3LydaxypMyYrbDFFp61f9rnZRcAJnZ5sv5	0.00000000	new
   m/49'/0'/1'/0/4     	36u2ykPy6Y9tg811B8XjYoPjpTtEg98RPd	0.00000000	new
   m/49'/0'/1'/0/5     	3AfSFczJEUN5RRbXirf8Pc74ve3ZaBVF8r	0.00000000	new
   Balance:	0.00000000
   internal addresses	m/49'/0'/1'/1
   Balance:	0.00000000
   Balance for mixdepth 1:	0.00000000
   mixdepth	2	xpub6Crt4fcfpnrP2Tjc95HKmSgaCpi9P9EM54B12XAUfdnyAyoftFpNyikSK4pBtsvqZAnj8grDFf61xDmAHYimQXvaQkoTY3h9G5BAxHuYgvn
   external addresses	m/49'/0'/2'/0	xpub6DrRZxJu5zEgxVMcrXmKGGeEQMgfh1MeZXvDXVYndqsqoFaJQUA94GbD1JX2p7Yw5NLcCUgg3WQXtXk5eP4vnNjGkDwA3FJoFFkE4PytauC
   m/49'/0'/2'/0/0     	39uPqzuW6CiyRSUvdrBYfaqSD2AtH2k4wf	0.00000000	new
   m/49'/0'/2'/0/1     	3FVYzJWE6g6kGj3hF7B5e7QpDQafBcUdnx	0.00000000	new
   m/49'/0'/2'/0/2     	3HjYatHB5tZFGcC2SUCBqT1zCM7AwgGE5r	0.00000000	new
   m/49'/0'/2'/0/3     	3CDco5iVa2iyEHGjXcAojsod6QDxeNedFg	0.00000000	new
   m/49'/0'/2'/0/4     	3LKaYFENU16ix8FngQk6m9VmQFGaATEeCu	0.00000000	new
   m/49'/0'/2'/0/5     	3B3TtgU6VgLF6BzQeG5znKZHpr3zgoftZC	0.00000000	new
   Balance:	0.00000000
   internal addresses	m/49'/0'/2'/1
   Balance:	0.00000000
   Balance for mixdepth 2:	0.00000000
   mixdepth	3	xpub6Crt4fcfpnrP5B7ysPePnY98sKaLAdu9yCbHpkodb6evSKhr4BWvpB7nQquPdzncTuhMxmUhEcVNuYpXQf9i6VN9DFYu3PgPMckuu4P7EeQ
   external addresses	m/49'/0'/3'/0	xpub6En2j7xGy2ihoYhpmTyDL1eER5B6rdas1HotoBiLbSXuXBMwZnjJTRefyJKVLUTfwDMgyATqZAwbZdKb8gQ8Fbno4XhUMPe6XBuN4LSsXN2
   m/49'/0'/3'/0/0     	3LhThkjSvYmmXLNLMcXghbvaoGgDitwfmi	0.00000000	new
   m/49'/0'/3'/0/1     	3LTwvukpZqsf9ghqnNQVu8szgScjoVnLdh	0.00000000	new
   m/49'/0'/3'/0/2     	35FRiSaZ6Yotr3YB3yX9JgqAbsxCnuTBfm	0.00000000	new
   m/49'/0'/3'/0/3     	3H7S5ZjYaWgSTXA1RFwGNytS2zsK1PfXoN	0.00000000	new
   m/49'/0'/3'/0/4     	33b8j2nPCFCWXb7wDHPRggUFoPJMwGQYYt	0.00000000	new
   m/49'/0'/3'/0/5     	3PE7fen989oPZn7XaRSAu3fvGN1P57SB9W	0.00000000	new
   Balance:	0.00000000
   internal addresses	m/49'/0'/3'/1
   Balance:	0.00000000
   Balance for mixdepth 3:	0.00000000
   mixdepth	4	xpub6Crt4fcfpnrP9pZBowaYjC7595HXETHFw2YnqtukLnqpfb4PWbhWwt5jPdskLo8ZZbHBnccexTJUArt4V8C7592K3LvsrYkrvsQMJFiPx8z
   external addresses	m/49'/0'/4'/0	xpub6E37s5W8C63FxsgcpMbH43ssUi8CQzfo3PrfSWfn9jKTYZgR4QZBCymJ8TPw3Vx5zoQ7aSgkqrEKr1NEerZuN8okV7w1JhNg2hoYEWohtT4
   m/49'/0'/4'/0/0     	39n1tYKnPQ47bgCmsPWDHxuk2Mxo6GE4LZ	0.00000000	new
   m/49'/0'/4'/0/1     	3BoLqHDSHdMHyrSEAP31bBzzw45bFwZhy7	0.00000000	new
   m/49'/0'/4'/0/2     	31mo7D9UDmoStafYcyHpwV9sWY7oP9jUVQ	0.00000000	new
   m/49'/0'/4'/0/3     	3JMVGEyZ5nyJR9NVsfNY93c34xx9rEtzmq	0.00000000	new
   m/49'/0'/4'/0/4     	3AdD86dw59Q5EGHVupkHzR8pM4sW45bKqX	0.00000000	new
   m/49'/0'/4'/0/5     	3Gu7jTxcmh5dHJXgCE7Z5fdMgUWuenE2GE	0.00000000	new
   Balance:	0.00000000
   internal addresses	m/49'/0'/4'/1
   Balance:	0.00000000
   Balance for mixdepth 4:	0.00000000
   Total balance:	0.00000000
   ```

   Bitcoin should be sent to one of the empty external addresses (sometimes known as receive addresses).

## Try out a coinjoin; using `sendpayment.py`

1. Single coinjoins can be done using the script `sendpayment.py`. As with all Joinmarket user scripts, use `--help` to see a full list of options.

   For example

   ```console
   $ sendpayment.py wallet.jmdat 5000000 mprGzBA9rQk82Ly41TsmpQGa8UPpZb2w8c
   ```

## Run the tumbler

The tumbler needs to be able to run in the background for a long time, use screen to run it accross ssh sessions.

1. Start the screen session

   ```console
   $ screen -S "tumbler"
   ```

2. Start the tumbler

   Example: Tumbling into your wallet after buying from an exchange to improve privacy:

   ```console
   $ tumbler.py wallet.jmdat 1NY1qw2SpHupJbk5WD9RW3G78NECVPMXi1 14FEGCh23fYb4sCFKj6JXUQv2jpcBOWj9y 166b5ePjQR6pkeA37LbgYhbaTVBFns74Lu 155jvPSRCJoWNETjAXNfgWaVptaL4HtHmY 1HCajpvGsgeU42EAyUMVuQ7y6rCsF8mo7
   ```

   The addresses are from the Addresses tab in Electrum. After tumbling is done you can spend bitcoins on normal things probably without the exchange collecting data on your purchases. All other parameters are left as default values.

   Get more information [here](https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/tumblerguide.md)

3. Detach screen session so you can leave ssh session

   ```
   Ctrl-a d or Ctrl-a Ctrl-d
   ```

4. View and interact with the screen session


   ```console
   $ screen -r tumbler
   ```

5. End screen session

   Type exit when tumbler is done

   ```console
   $ exit
   ```
## Run a "Maker" or "yield generator"

The maker/yield generator in nix-bitcoin is implemented using a systemd service.

Click [here](https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/YIELDGENERATOR.md) for general yield generator information.

In nix-bitcoin the yg-privacyenhanced.py script is located in the system path. If you want to custom configure it, the easiest way to find it is by running `whereis yg-privacyenhanced.py`.

1. Enable Yield Generator Bot

   Change
   ```
   # services.joinmarket.yieldgenerator = true;
   ```
   to
   ```
   services.joinmarket.yieldgenerator = true;
   ```
   in your `configuration.nix`

2. Deploy to your node, for example

   ```console
   $ nix-shell
   $ nixops deploy
   ```

3. SSH into your nix-bitcoin node as root

   ```console
   $ nix-shell
   $ nixops ssh root@bitcoin-node
   ```

4. Start systemd service

   ```console
   # systemctl start joinmarket-yieldgenerator
   ```

5. Head to your joinmarket data directory (default /var/lib/joinmarket/) and record your wallet.jmdat password in the newly created `joinmarket-wallet-password`

6. Restart systemd service so it can read your wallet password

   ```console
   # systemctl restart joinmarket-wallet-password
   ```

7. Profit
