{ inputs, lib, pkgs, config, ... }:
let
  inherit (inputs.nix-colors) colorSchemes;
in
{
  imports = [
    ./common
    ./common/cli
    ./common/nvim
    ./common/desktop/common
  ];

  # Use this method for built-in schemes:
  colorscheme = lib.mkDefault colorSchemes.primer-dark-dimmed;

  # Use this method for custom imported schemes:
  # colorscheme = lib.mkDefault customSchemes.gruvchad;

  # All colorschemes from here can be set: https://tinted-theming.github.io/base16-gallery/
  # current favorites (apart from gruvchad): primer-dark-dimmed, tokyo-city-terminal-dark

  defaultWallpaper = builtins.toString ./common/desktop/backgrounds/wolf.png;
  #  ------
  # | DP-2 |
  #  ------
  #  ------
  # | DP-3 |
  #  ------
  monitors = [
    {
      name = "DP-2";
      width = 2560;
      height = 1440;
      x = 0;
      y = 0;
      workspaces = [ "1" "3" "5" "7" "9" ];
    }
    {
      name = "DP-3";
      width = 2560;
      height = 1440;
      x = 0;
      y = 1440;
      workspaces = [ "2" "4" "6" "8" "10" ];
      # wallpaper = builtins.toString ./common/desktop/backgrounds/river.png;
      primary = true;
    }
  ];


  # Projects to manage on this machine
  projects = [{ name = "nix"; repo = "git@github.com:charludo/nix"; enableDirenv = false; }];

  # XDG dirs are (partly) symlinks to an external drive
  xdg.userDirs.extraConfig.XDG_CREATIVITY_DIR = "${config.home.homeDirectory}/Creativity";
  home.file = {
    "${config.xdg.userDirs.extraConfig.XDG_CREATIVITY_DIR}".source = config.lib.file.mkOutOfStoreSymlink "/media/Media/Kreatives";
    "${config.xdg.userDirs.documents}".source = config.lib.file.mkOutOfStoreSymlink "/media/Media/Dokumente";
    "${config.xdg.userDirs.music}".source = config.lib.file.mkOutOfStoreSymlink "/media/Media/Musik";
    "${config.xdg.userDirs.pictures}".source = config.lib.file.mkOutOfStoreSymlink "/media/Media/Fotos";
    "${config.xdg.userDirs.videos}".source = config.lib.file.mkOutOfStoreSymlink "/media/Media/Videos";
  };

  # Otherwise way to big on hub
  programs.alacritty.settings.font.size = lib.mkForce 13;
}
