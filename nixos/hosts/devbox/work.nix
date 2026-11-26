# Tooling for work projects on devbox
{
  config,
  pkgs,
  ...
}:
{
  nixpkgs.config.allowUnfreePackages = [ "pritunl-client" ];

  environment.systemPackages = with pkgs; [
    pritunl-client
    azure-cli
    argocd
    go
    (callPackage ./tsh.nix { })
  ];

  # The CLI only talks to this daemon, which owns the OpenVPN tunnels
  systemd.packages = [ pkgs.pritunl-client ];
  systemd.services.pritunl-client.wantedBy = [ "multi-user.target" ];

  # tailscaled marks its own packets 0x80000: pin them to the LAN gateway so no VPN route
  # (full tunnel included) can carry them and cut SSH over Tailscale
  environment.etc."systemd/network/10-cloud-init-eth0.network.d/tailscale-underlay.conf".text = ''
    [Route]
    Gateway=192.168.1.254
    Table=200

    [Route]
    Destination=192.168.1.0/24
    Scope=link
    Table=200

    [RoutingPolicyRule]
    FirewallMark=0x80000/0xff0000
    Table=200
    Priority=5200
  '';
  systemd.services.systemd-networkd.restartTriggers = [
    config.environment.etc."systemd/network/10-cloud-init-eth0.network.d/tailscale-underlay.conf".source
  ];
}
