{ config, lib, pkgs, ... }:

{
  imports = [
    ./autopilot.nix
    ./donations.nix
    ./drain.nix
    ./feeadjuster.nix
    ./helpme.nix
    ./jitrebalance.nix
    ./monitor.nix
    ./persistent-channels.nix
    ./probe.nix
    ./prometheus.nix
    ./rebalance.nix
    ./sendinvoiceless.nix
    ./summary.nix
    ./zmq.nix
  ];
}
