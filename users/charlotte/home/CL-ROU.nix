{
  inputs,
  lib,
  pkgs,
  config,
  private-settings,
  ...
}:
let
  inherit (inputs.nix-colors) colorSchemes;
  # deadnix: skip
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
  ];

  home.packages = [ pkgs.tmux ];
  home.hostname = "CL-ROU";

  # Use this method for built-in schemes:
  colorScheme = lib.mkDefault colorSchemes.primer-dark-dimmed;

  # Use this method for custom imported schemes:
  # colorScheme = lib.mkDefault customSchemes.gruvchad;

  # All colorSchemes from here can be set: https://tinted-theming.github.io/base16-gallery/
  # current favorites (apart from gruvchad): primer-dark-dimmed, tokyo-city-terminal-dark

  # Projects to manage on this machine
  xdg.userDirs.extraConfig = {
    XDG_PROJECTS_DIR = "${config.home.homeDirectory}/Projekte";
  };
  projects = private-settings.projects;

  nixvim.enable = true;
  nixvim.addDesktopEntry = false;
  nixvim.languages = {
    python.enable = true;
    rust.enable = true;
    webdev.enable = true;
  };
}
