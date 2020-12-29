<br/>
<br/>
<p align="center">
  <img
    width="320"
    src="docs/img/nix-bitcoin-logo.png"
    alt="nix-bitcoin logo">
</p>
<br/>
<p align="center">
    <a href="https://github.com/fort-nix/nix-bitcoin/blob/master/LICENSE" target="_blank">
        <img src="https://img.shields.io/github/license/fort-nix/nix-bitcoin" alt="GitHub license">
    </a>
    <a href="https://github.com/fort-nix/nix-bitcoin/releases/latest" target="_blank">
        <img src="https://img.shields.io/github/v/release/fort-nix/nix-bitcoin" alt="GitHub tag (latest SemVer)">
    </a>
    <a href="https://cirrus-ci.com/github/fort-nix/nix-bitcoin" target="_blank">
        <img src="https://api.cirrus-ci.com/github/fort-nix/nix-bitcoin.svg?branch=master" alt="CirrusCI actions status">
    </a>
    <a href="https://github.com/fort-nix/nix-bitcoin/commits/master" target="_blank">
        <img src="https://img.shields.io/github/commit-activity/y/fort-nix/nix-bitcoin" alt="GitHub commit activity">
    </a>
    <a href="https://github.com/fort-nix/nix-bitcoin/graphs/contributors" target="_blank">
        <img src="https://img.shields.io/github/contributors-anon/fort-nix/nix-bitcoin" alt="GitHub contributors">
    </a>
    <a href="https://github.com/fort-nix/nix-bitcoin/releases" target="_blank">
        <img src="https://img.shields.io/github/downloads/fort-nix/nix-bitcoin/total" alt="GitHub downloads">
    </a>
</p>
<br/>

nix-bitcoin is a collection of Nix packages and NixOS modules for easily installing **full-featured Bitcoin nodes** with an emphasis on **security**.

Goals
---
* Make it easy to deploy a secure Bitcoin node with a usable wallet
* Allow providing public infrastructure for Bitcoin and higher-layer protocols
* Be a usable, secure platform for trustless Bitcoin yield generation
* Be a reproducible and extensible platform for applications building on Bitcoin

Features
---
Default
* bitcoind with outbound connections through Tor and inbound connections through an onion service. By default loaded with banlist of spy nodes.
* [clightning](https://github.com/ElementsProject/lightning) with outbound connections through Tor, onion service unannounced
* includes "nodeinfo" script which prints basic info about the node
* adds non-root user "operator" who has access to client tools (ex. bitcoin-cli, lightning-cli)

In `configuration.nix` the user can enable
* announcing a clightning onion service and [clightning plugins](https://github.com/lightningd/plugins):
  * [clboss](https://github.com/ZmnSCPxj/clboss): Automated C-Lightning Node Manager
  * [helpme](https://github.com/lightningd/plugins/tree/master/helpme): Walks you through setting up a fresh c-lightning node
  * [monitor](https://github.com/renepickhardt/plugins/tree/master/monitor): Helps you analyze the health of your peers and channels
  * [prometheus](https://github.com/lightningd/plugins/tree/master/prometheus): Lightning node exporter for the prometheus timeseries server
  * [rebalance](https://github.com/lightningd/plugins/tree/master/rebalance): Keeps your channels balanced
  * [summary](https://github.com/lightningd/plugins/tree/master/summary): Print a nice summary of the node status
  * [zmq](https://github.com/lightningd/plugins/tree/master/zmq): Publishes notifications via ZeroMQ to configured endpoints
* [lnd](https://github.com/lightningnetwork/lnd) with or wihtout announcing an onion service
* [spark-wallet](https://github.com/shesek/spark-wallet)
* [electrs](https://github.com/romanz/electrs)
* [btcpayserver](https://github.com/btcpayserver/btcpayserver)
* [liquid](https://github.com/elementsproject/elements)
* [lightning charge](https://github.com/ElementsProject/lightning-charge) (deprecated)
* [nanopos](https://github.com/ElementsProject/nanopos) (deprecated)
* [nix-bitcoin webindex](modules/nix-bitcoin-webindex.nix), an index page using nginx to display node information and link to nanopos
* [recurring-donations](modules/recurring-donations.nix), a module to repeatedly send lightning payments to recipients specified in the configuration.
* [bitcoin-core-hwi](https://github.com/bitcoin-core/HWI)
* [netns-isolation](modules/netns-isolation.nix), isolates modules/services on a network-level in network namespaces
* [Lightning Loop](https://github.com/lightninglabs/loop)
* [backups](modules/backups.nix), daily duplicity backups of all your nodes important files
* [JoinMarket](https://github.com/joinmarket-org/joinmarket-clientserver)

Security
---
* **Simplicity:** Only services you select in `configuration.nix` and their dependencies are installed, packages and dependencies are [pinned](pkgs/nixpkgs-pinned.nix), most packages are built from the [NixOS stable channel](https://github.com/NixOS/nixpkgs/tree/nixos-20.09), with a few exceptions that are built from the nixpkgs unstable channel, builds happen in a [sandboxed environment](https://nixos.org/manual/nix/stable/#conf-sandbox), code is continuously reviewed and refined.
* **Integrity:** Nix package manager, NixOS and packages can be built from source to reduce reliance on binary caches, nix-bitcoin merge commits are signed, all commits are approved by multiple nix-bitcoin developers, upstream packages are cryptographically verified where possible, we use this software ourselves.
* **Principle of Least Privilege:** Services operate with least privileges; they each have their own user and are restricted further with [systemd options](modules/nix-bitcoin-services.nix), [RPC whitelisting](modules/bitcoind-rpc-public-whitelist.nix), and [netns-isolation](modules/netns-isolation.nix). There's a non-root user *operator* to interact with the various services.
* **Defense-in-depth:** nix-bitcoin is built with a [hardened kernel](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/hardened.nix) by default, services are confined through discretionary access control, Linux namespaces, [dbus firewall](modules/security.nix) and seccomp-bpf with continuous improvements.

Note that if the machine you're deploying *from* is insecure, there is nothing nix-bitcoin can do to protect itself.

Examples
---
Example `configuration.nix` and scripts, from which you can build your own deployment, can be found in the [examples directory](examples).

Docs
---
* [FAQ](docs/faq.md)
* [Hardware Requirements](docs/hardware.md)
* [Install instructions](docs/install.md)
* [Usage instructions](docs/usage.md)

Troubleshooting
---
If you are having problems with nix-bitcoin check the [FAQ](docs/faq.md) or submit an issue.
There's also a `#nix-bitcoin` IRC channel on freenode.
We are always happy to help.
