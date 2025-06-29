{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.desktop.yubikey-notify;
in
{
  options.desktop.yubikey-notify = {
    enable = mkEnableOption "notify when Yubikey is waiting for touch";

    package = mkOption {
      type = types.package;
      default = pkgs.yubikey-touch-detector;
      defaultText = "pkgs.yubikey-touch-detector";
      description = ''
        Package to use.
      '';
    };

    socket.enable = mkEnableOption "start the process only when the socket is used";

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ "--libnotify" ];
      defaultText = literalExpression ''[ "--libnotify" ]'';
      description = ''
        Extra arguments to pass to the tool. The arguments are not escaped.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    systemd.user.sockets.yubikey-touch-detector = mkIf cfg.socket.enable {
      Unit.Description = "Unix socket activation for Yubikey touch detector service";
      Socket = {
        ListenFIFO = "%t/yubikey-touch-detector.sock";
        RemoveOnStop = true;
        SocketMode = "0660";
      };
    };

    systemd.user.services.yubikey-notify = {
      Unit = {
        Descriptin = "Detects and notifies when Yubikey is waiting for touch";
        Requires = optionals cfg.socket.enable [ "yubikey-touch-detector.socket" ];
      };
      Service = {
        ExecStart = "${cfg.package}/bin/yubikey-touch-detector ${concatStringsSep " " cfg.extraArgs}";
        Environment = [ "PATH=${lib.makeBinPath [ pkgs.gnupg ]}" ];
        Restart = "on-failure";
        RestartSec = "1sec";
      };
      Install.Also = optionals cfg.socket.enable [ "yubikey-touch-detector.socket" ];
      Install.WantedBy = [ "default.target" ];
    };
  };
}
