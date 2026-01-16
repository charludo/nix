{
  config,
  lib,
  pkgs,
  private-settings,
  ...
}:
{
  imports = [
    ../../../charlotte/home/common/nix.nix
    ../../../charlotte/home/common/theme.nix
  ];

  nixvim.enable = true;

  age.enable = true;
  gpg.enable = lib.mkDefault true;

  cli = {
    bat.enable = true;
    fish.enable = true;
    fzf.enable = true;
    git = {
      enable = true;
      sshKey.pub = ../../keys/ssh.pub;
      user.name = private-settings.git.marie.name;
      user.email = private-settings.git.marie.email;
    };
  };

  desktop = {
    alacritty.enable = true;
    firefox = {
      enable = true;
      profileName = "marie";
      extraSearchEngines = true;
      extraConfig = {
        "browser.search.widget.inNavBar" = true;
      };
    };
    vscode.enable = true;
  };

  services.remmina.enable = true;

  home.packages = with pkgs; [
    # additional user-specific packages go here
    cowsay
  ];

  programs.bash = {
    enable = true;
    sessionVariables = {
      AGENIX_REKEY_PRIMARY_IDENTITY = "${builtins.readFile ../../keys/ssh.pub}";
      AGENIX_REKEY_PRIMARY_IDENTITY_ONLY = "true";
    };
  };

  programs.home-manager.enable = true;
  home = {
    username = lib.mkDefault "marie";
    homeDirectory = lib.mkDefault "/home/${config.home.username}";
    stateVersion = lib.mkDefault "23.11";
    sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
    sessionVariables = {
      FLAKE = "${config.home.homeDirectory}/nix";
      EDITOR = "nano";
    };
    language.base = "en_US.UTF-8";
  };
}
