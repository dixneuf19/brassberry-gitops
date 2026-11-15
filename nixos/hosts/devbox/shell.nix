# Interactive shell: zsh with oh-my-zsh and powerlevel10k
{ pkgs, ... }:
{
  users.users.dixneuf19.shell = pkgs.zsh;
  # Without a ~/.zshrc, zsh opens its new user wizard on first login
  systemd.tmpfiles.rules = [ "f /home/dixneuf19/.zshrc 0644 dixneuf19 users -" ];

  programs.zsh = {
    enable = true;
    ohMyZsh = {
      enable = true;
      plugins = [
        "git"
        "common-aliases"
        "docker"
        "helm"
        "kubectl"
        "fzf"
        "terraform"
      ];
    };
    promptInit = ''
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/config/p10k-lean-8colors.zsh
      # Plain glyphs, so the prompt renders over SSH without a Nerd Font
      POWERLEVEL9K_MODE=ascii
    '';
    shellAliases = {
      ks = "k9s";
    };
  };

  programs.zoxide.enable = true;

  # Skip commands typed with a leading space, like zsh with oh-my-zsh
  programs.bash.interactiveShellInit = "HISTCONTROL=ignoreboth";

  environment.systemPackages = with pkgs; [
    k9s
    fzf
  ];
}
