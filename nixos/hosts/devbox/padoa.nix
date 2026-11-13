# Tooling for Padoa work on devbox
{ lib, pkgs, ... }:
{
  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "pritunl-client";

  environment.systemPackages = with pkgs; [
    pritunl-client
    azure-cli
    argocd
  ];

  # The CLI only talks to this daemon, which owns the OpenVPN tunnels
  systemd.packages = [ pkgs.pritunl-client ];
  systemd.services.pritunl-client.wantedBy = [ "multi-user.target" ];
}
