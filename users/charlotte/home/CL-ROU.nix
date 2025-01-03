{ inputs, lib, pkgs, config, ... }:
let
  customWaybarModules = import ./common/desktop/hyprland/waybar/modules.nix { inherit pkgs config; };
  inherit (inputs.nix-colors) colorschemes;
  customSchemes = import ./common/desktop/common/customColorSchemes.nix;
in
{
  imports = [
    ./common
    ./common/cli/bat.nix
    ./common/cli/direnv.nix
    ./common/cli/fish.nix
    ./common/cli/fzf.nix
    ./common/cli/gh.nix
    ./common/cli/git.nix
    ./common/nvim
  ];

  home.packages = [ pkgs.tmux ];

  # Use this method for built-in schemes:
  colorscheme = lib.mkDefault colorschemes.primer-dark-dimmed;

  # Use this method for custom imported schemes:
  # colorscheme = lib.mkDefault customSchemes.gruvchad;

  # All colorschemes from here can be set: https://tinted-theming.github.io/base16-gallery/
  # current favorites (apart from gruvchad): primer-dark-dimmed, tokyo-city-terminal-dark

  # Projects to manage on this machine
  xdg.userDirs.extraConfig = {
    XDG_PROJECTS_DIR = "${config.home.homeDirectory}/Projekte";
  };
  projects = inputs.private-settings.projects;
}
