# Everything a homelab NixOS VM needs to join the tailnet and keep itself in sync
# with main. Shared by the base image and every host.
{ lib, modulesPath, ... }:
{
  imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];

  system.stateVersion = "26.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.growPartition = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  time.timeZone = "Europe/Paris";

  # Hostname and static address come from Proxmox cloud-init; the host
  # config pins the hostname once it takes over
  networking.hostName = lib.mkDefault "";
  networking.useNetworkd = true;
  services.cloud-init = {
    enable = true;
    network.enable = true;
  };

  services.qemuGuest.enable = true;

  users.mutableUsers = false;
  users.users.dixneuf19 = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keyFiles = [ ./dixneuf19.pub ];
  };
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # The key is single use and written by cloud-init on first boot; tags come from the key
  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = "/var/lib/tailscale/authkey";
  };
  # Register only once cloud-init has set the hostname, which becomes the tailnet name
  systemd.services.tailscaled-autoconnect.after = [ "cloud-init.service" ];

  networking.firewall.enable = true;

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [ "@wheel" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  system.autoUpgrade = {
    enable = true;
    flake = "github:dixneuf19/brassberry-gitops?dir=nixos";
    dates = "*:0/15";
    allowReboot = false;
  };
  systemd.timers.nixos-upgrade.timerConfig.OnBootSec = "2min";
}
