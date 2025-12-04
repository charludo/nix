{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./nix.nix
    ./theme.nix
    ./secrets.nix
  ];

  nixvim.enable = true;

  age.enable = true;
  gpg.enable = lib.mkDefault true;
  ssh.enable = lib.mkDefault true;
  xdgProfile.enable = lib.mkDefault true;

  programs.home-manager.enable = true;
  home = {
    username = lib.mkDefault "charlotte";
    homeDirectory = lib.mkDefault "/home/${config.home.username}";
    stateVersion = lib.mkDefault "23.11";
    sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
    sessionVariables = {
      FLAKE = "${config.home.homeDirectory}/Projekte/nix";
      EDITOR = "nvim";
      TERMINAL = "${lib.getExe pkgs.alacritty}";
    };
    language.base = "en_US.UTF-8";
  };
}
