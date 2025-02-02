{
  lib,
  pkgs,
  config,
  outputs,
  ...
}:
{
  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  nix = {
    package = lib.mkDefault pkgs.nix;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
    };
  };

  age.enable = true;
  services.yubikey-notify.enable = true;

  programs.home-manager.enable = true;
  home = {
    username = lib.mkDefault "charlotte";
    homeDirectory = lib.mkDefault "/home/${config.home.username}";
    stateVersion = lib.mkDefault "23.11";
    sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
    sessionVariables = {
      FLAKE = "${config.home.homeDirectory}/Projekte/nix";
      EDITOR = "nvim";
      TERMINAL = "${pkgs.alacritty}/bin/alacritty";
    };
    language.base = "en_US.UTF-8";
  };
}
