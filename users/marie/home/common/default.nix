{
  config,
  lib,
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
  xdgProfile.enable = lib.mkDefault true;

  cli = {
    bat.enable = true;
    fzf.enable = true;
    git = {
      enable = true;
      sshKey.pub = ../../keys/ssh.pub;
      user.name = private-settings.git.marie.name;
      user.email = private-settings.git.marie.email;
    };
  };

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
