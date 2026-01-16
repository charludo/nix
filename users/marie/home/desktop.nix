{ config, private-settings, ... }:
{
  imports = [
    ./common
  ];
  home.hostname = "desktop";
  home.stateVersion = "25.11";
  agenix-rekey.pubkey = ../keys/ssh.pub;

  programs.onlyoffice.enable = true;
  desktop = {
    element.enable = true;
    discord.enable = true;
    jellyfin.enable = true;
    thunderbird.enable = true;
    thunderbird.profileName = "marie";
  };
  xdgProfile.enable = true;
  xdg.userDirs.desktop = "${config.home.homeDirectory}/Desktop";
  xdg.userDirs.extraConfig.XDG_PROJECTS_DIR = config.home.homeDirectory;

  fontProfiles.monospace.size = 13;
  programs.alacritty.settings.window.padding.x = 0;
  programs.alacritty.settings.window.padding.y = 0;

  projects = private-settings.just-nix-projects;
  accounts.email.accounts = private-settings.marie.accounts;
}
