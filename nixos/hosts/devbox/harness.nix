# Tooling for running coding agents and their harnesses on devbox
{
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:
let
  # The claude-code wrapper prepends its own alsa-lib to LD_LIBRARY_PATH and every command it runs inherits it
  withoutInheritedLibs =
    pkg:
    pkgs.symlinkJoin {
      name = "${pkg.pname}-clean-env";
      paths = [ pkg ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        for f in $out/bin/*; do
          wrapProgram "$f" --unset LD_LIBRARY_PATH
        done
      '';
      meta.mainProgram = pkg.meta.mainProgram;
    };
in
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
    vim
    helix
    unzip
    gnumake
    gcc
    nodejs
    python3
    uv
    kubectl
    kubernetes-helm
    k0sctl
    # IaC CLIs used by the repo .envrc; tfswitch installs the exact terraform pinned in each root
    tfswitch
    scaleway-cli
    bws
  ])
  ++ map withoutInheritedLibs [
    pkgs.chromium
    pkgs.playwright-mcp
  ];

  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "bws";

  # tfswitch drops the terraform binary in ~/bin
  environment.homeBinInPath = true;

  virtualisation.docker.enable = true;
  users.users.dixneuf19.extraGroups = [ "docker" ];

  # Lets prebuilt Linux binaries run (npm native modules, pip wheels, Playwright, downloaded tools)
  programs.nix-ld.enable = true;

  programs.direnv = {
    enable = true;
    # git worktrees get a copy of the tracked .envrc at a path that was never `direnv allow`ed
    settings.whitelist.prefix = [ "/home/dixneuf19/codes/perso" ];
  };

  # Claude Code sources this line before every Bash command, so each one gets the direnv env of its own cwd
  environment.etc."claude-code/managed-settings.json".text = builtins.toJSON {
    hooks.SessionStart = [
      {
        hooks = [
          {
            type = "command";
            command = ''echo 'eval "$(direnv export bash 2>/dev/null)"' >> "$CLAUDE_ENV_FILE"'';
            timeout = 5;
          }
        ];
      }
    ];
  };

  # Rex terminals open in ~ by default, where Claude Code never remembers folder trust (bash and zsh)
  environment.interactiveShellInit = ''
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
