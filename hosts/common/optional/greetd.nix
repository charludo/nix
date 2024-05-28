{ config, pkgs, ... }:
{
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "Hyprland";
        user = config._module.args.defaultUser;
      };
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet -r --remember-user-session --asterisks --cmd \"Hyprland\"";
      };
    };
  };

}
