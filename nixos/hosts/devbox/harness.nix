# Tooling for running coding agents and their harnesses on devbox
{
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:
{
  environment.systemPackages = [
    # Follows Anthropic releases ahead of nixpkgs; .github/workflows/claude-code-pin.yaml bumps the manifest
    (pkgsUnstable.claude-code.override { manifest = lib.importJSON ./claude-code-manifest.json; })
  ]
  ++ (with pkgsUnstable; [
    pi-coding-agent
    rtk
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
    kubectl
    kubernetes-helm
  ]);

  virtualisation.docker.enable = true;
  users.users.dixneuf19.extraGroups = [ "docker" ];

  # Lets prebuilt Linux binaries run (npm native modules, pip wheels, Playwright, downloaded tools)
  programs.nix-ld.enable = true;

  programs.direnv.enable = true;

  # Rex terminals open in ~ by default, where Claude Code never remembers folder trust
  programs.bash.interactiveShellInit = ''
    [[ -n $REX_SESSION && $PWD == "$HOME" ]] && cd ~/codes
  '';

  programs.git = {
    enable = true;
    config.user = {
      name = "Julen Dixneuf";
      email = "1516762+dixneuf19@users.noreply.github.com";
    };
  };
}
