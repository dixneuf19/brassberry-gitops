# Tooling for running coding agents and their harnesses on devbox
{ pkgs, pkgsUnstable, ... }:
{
  environment.systemPackages =
    (with pkgsUnstable; [
      claude-code
      pi-coding-agent
    ])
    ++ (with pkgs; [
      git
      gh
      jq
      ripgrep
      fd
      curl
      htop
      neovim
      unzip
      gnumake
      gcc
      nodejs
      python3
      uv
    ]);

  virtualisation.docker.enable = true;
  users.users.dixneuf19.extraGroups = [ "docker" ];

  # Lets prebuilt Linux binaries run (npm native modules, pip wheels, Playwright, downloaded tools)
  programs.nix-ld.enable = true;

  programs.direnv.enable = true;
}
