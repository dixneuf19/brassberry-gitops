# Keeps the agent orchestrator up across reboots: a personal Rex server and the "orchestrator" Rex session start at boot
{
  config,
  lib,
  pkgs,
  ...
}:
let
  rex = config.services.rex.package;
in
{
  users.users.dixneuf19.linger = true;

  # Same shape as the user service of Rex's home-manager module; the login server reuses this server
  systemd.user.services.rex-server = {
    description = "Rex personal server";
    wantedBy = [ "default.target" ];
    environment = {
      TERMINFO_DIRS = "${rex}/share/terminfo";
      GODEBUG = "";
    };
    serviceConfig = {
      ExecStart = "${lib.getExe rex} server run --log-format text";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  # ~/.local/bin/orchestrator is idempotent: it creates the Rex session only when it is missing
  systemd.user.services.orchestrator = {
    description = "Devbox agent orchestrator session";
    after = [ "rex-server.service" ];
    requires = [ "rex-server.service" ];
    wantedBy = [ "default.target" ];
    path = [
      "/run/current-system/sw"
      rex
    ];
    unitConfig.ConditionPathExists = "%h/.local/bin/orchestrator";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
      ExecStart = "%h/.local/bin/orchestrator";
    };
  };
}
