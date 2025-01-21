{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.plymouth;
in
{
  options.plymouth = {
    enable = lib.mkEnableOption (lib.mdDoc "enable plymouth splash screen during boot");

    theme = mkOption {
      type = types.str;
      description = "which theme to show";
      example = "rings, red_loader, hud_3, dark_planet, cuts";
    };
  };

  config = mkIf cfg.enable {
    boot = {
      plymouth = {
        enable = true;
        theme = cfg.theme;
        themePackages = with pkgs; [
          (adi1090x-plymouth-themes.override {
            selected_themes = [ cfg.theme ];
          })
        ];
      };

      consoleLogLevel = 0;
      initrd.verbose = false;
      kernelParams = [
        "quiet"
        "splash"
        "boot.shell_on_fail"
        "loglevel=3"
        "rd.systemd.show_status=false"
        "rd.udev.log_level=3"
        "udev.log_priority=3"
      ];
    };
  };
}
