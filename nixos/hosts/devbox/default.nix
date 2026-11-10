{
  imports = [
    ./harness.nix
    ./orchestrator.nix
  ];

  networking.hostName = "devbox";

  services.rex.loginServer = {
    enable = true;
    accounts = {
      dixneuf19.principals = [ "tailscale:dixneuf19@github" ];
      root.principals = [ "tailscale:dixneuf19@github" ];
    };
    defaults."tailscale:dixneuf19@github" = "dixneuf19";
    tailscaleServe.enable = true;
  };
}
