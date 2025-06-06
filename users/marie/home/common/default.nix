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
  programs.home-manager.enable = true;

  programs.bash = {
    enable = true;
    sessionVariables = {
      AGENIX_REKEY_PRIMARY_IDENTITY = "${builtins.readFile ../../ssh.pub}";
      AGENIX_REKEY_PRIMARY_IDENTITY_ONLY = true;
    };
  };

  home = {
    username = lib.mkDefault "marie";
    homeDirectory = lib.mkDefault "/home/${config.home.username}";
    stateVersion = lib.mkDefault "23.11";
    sessionPath = [ "$HOME/.local/bin" ];
    sessionVariables = {
      FLAKE = "$HOME/nix";
      EDITOR = "nano";
    };
    language.base = "en_US.UTF-8";
  };
}
