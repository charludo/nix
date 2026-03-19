{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.greetd;
in
{
  options.greetd = {
    enable = mkEnableOption "greetd";
    defaultUser = mkOption {
      type = types.str;
      default = "charlotte";
      description = "default user to be logged in";
    };
    autoLogin = mkOption {
      type = types.bool;
      default = true;
      description = "enable automatic defaultUser login";
    };
  };

  config = mkIf cfg.enable {
    services.greetd = {
      enable = true;
      settings = {
        initial_session = lib.mkIf cfg.autoLogin {
          command = "Hyprland";
          user = cfg.defaultUser;
        };
        default_session = {
          command = "${lib.getExe pkgs.tuigreet} -r --remember-user-session --asterisks --cmd \"Hyprland\"";
        };
      };
    };
    environment.variables.XDG_RUNTIME_DIR = "/run/user/$UID";
  };
}
