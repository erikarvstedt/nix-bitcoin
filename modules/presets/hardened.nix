{
  imports = [
    # Source: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/hardened.nix
    <nixpkgs/nixos/modules/profiles/hardened.nix>
  ];

  ## Reset some options set by the hardened profile

  # Needed for sandboxed builds and services
  security.allowUserNamespaces = true;

  # The "scudo" allocator is broken on NixOS 20.09
  environment.memoryAllocator.provider = "libc";

  ## Settings from madaidan's Linux Hardening Guide
  # See https://madaidans-insecurities.github.io/guides/linux-hardening.html
  # for detailed explanations

  boot.kernel.sysctl = {
    # Prevent boot console kernel log information leaks
    "kernel.printk" = "3 3 3 3";

    # Restrict loading TTY line disciplines to the CAP_SYS_MODULE capability to
    # prevent unprivileged attackers from loading vulnerable line disciplines with
    # the TIOCSETD ioctl
    "dev.tty.ldisc_autoload" = "0";

    # The SysRq key exposes a lot of potentially dangerous debugging functionality
    # to unprivileged users
    "kernel.sysrq" = "4";

    # Protect against time-wait assassination by dropping RST packets for sockets
    # in the time-wait state
    "net.ipv4.tcp_rfc1337" = "1";

    # Ignore all ICMP requests to avoid Smurf attacks, make the device more
    # difficult to enumerate on the network and prevent clock fingerprinting
    # through ICMP timestamps
    "net.ipv4.icmp_echo_ignore_all" = "1";

    # Disable malicious IPv6 router advertisements
    "net.ipv6.conf.all.accept_ra" = "0";
    "net.ipv6.default.accept_ra" = "0";

    # Disable TCP SACK. SACK is commonly exploited and unnecessary for many
    # circumstances so it should be disabled if you don't require it
    "net.ipv4.tcp_sack" = "0";
    "net.ipv4.tcp_dsack" = "0";

    # Restrict usage of ptrace to only processes with the CAP_SYS_PTRACE
    # capability
    "kernel.yama.ptrace_scope" = "2";

    # Prevent creating files in potentially attacker-controlled environments such
    # as world-writable directories to make data spoofing attacks more difficult
    "fs.protected_fifos" = "2";
    "fs.protected_regular" = "2";

    # Avoid leaking system time with TCP timestamps
    "net.ipv4.tcp_timestamps" = "0";

    # Disable core dumps
    "syskernel.core_pattern" = "|/bin/false";
    "fs.suid_dumpable" = "0";

    # Only swap when absolutely necessary
    "vm.swappiness" = "1";
  };
}
