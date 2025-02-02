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
    enable = mkEnableOption "enable greetd";
    defaultUser = mkOption {
      type = types.str;
      default = "charlotte";
      description = "default user to be logged in";
    };
  };

  config = mkIf cfg.enable {
    services.greetd = {
      enable = true;
      settings = {
        initial_session = {
          command = "Hyprland";
          user = cfg.defaultUser;
        };
        default_session = {
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet -r --remember-user-session --asterisks --cmd \"Hyprland\"";
        };
      };
    };
    environment.variables.XDG_RUNTIME_DIR = "/run/user/$UID";
  };
}
