{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop.nemo;
in
{
  options.desktop.nemo.enable = lib.mkEnableOption "Nemo file manager";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      nemo-with-extensions
      nemo-fileroller
    ];

    dconf = {
      settings = {
        "org/cinnamon/desktop/applications/terminal" = {
          exec = "alacritty";
          exec-arg = "-e fish";
        };
        "org/nemo/preferences" = {
          thumbnail-limit = "104857600";
        };
      };
    };

    xdg.desktopEntries.nemo = {
      name = "Nemo";
      type = "Application";
      comment = "Access and organize files";
      terminal = false;
      exec = "nemo %U";
      categories = [
        "Utility"
        "Core"
      ];
      icon = "system-file-manager";
      mimeType = [
        "inode/directory"
        "application/x-gnome-saved-search"
      ];
      actions = {
        "open-home" = {
          name = "Home";
          exec = "nemo %U";
        };
        "open-computer" = {
          name = "Computer";
          exec = "name computer:///";
        };
        "open-trash" = {
          name = "Trash";
          exec = "nemo trash:///";
        };
      };
    };
  };
}
