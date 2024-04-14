{ pkgs, config, lib, ... }:
let ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  sops.secrets.charlotte-password = { neededForUsers = true; };

  users.users.charlotte = {
    isNormalUser = true;
    shell = pkgs.zsh;

    uid = 1000;
    group = "charlotte";
    extraGroups = [
      "wheel"
      "video"
      "audio"
      "networkmanager"
    ] ++ ifTheyExist [
      "docker"
      "git"
    ];

    openssh.authorizedKeys.keys = [ (builtins.readFile ./ssh.pub) ];
    hashedPasswordFile = config.sops.secrets.charlotte-password.path;
    packages = with pkgs; [ home-manager git ];
  };

  users.groups.charlotte.gid = 1000;

  security.sudo.extraRules = [
    {
      users = [ "charlotte" ];
      commands = [
        {
          command = "ALL";
          options = [ "SETENV" ];
        }
      ];
    }
  ];

  home-manager.users.charlotte = import ./home/${config.networking.hostName}.nix;
  environment.shells = with pkgs; [ zsh bash ];

  # It sucks that this is here, but thunar won't properly work otherwise / when installed through home-manager
  environment.sessionVariables.GIO_EXTRA_MODULES = lib.mkDefault "$GIO_EXTRA_MODULES:${config.services.gvfs.package}/lib/gio/modules";
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  programs.thunar.enable = true;
  programs.thunar.plugins = with pkgs.xfce; [
    thunar-archive-plugin
    thunar-volman
  ];

  fonts.fontconfig = {
    enable = true;

    antialias = true;

    subpixel.lcdfilter = "default";

    allowBitmaps = true;
    useEmbeddedBitmaps = true;

    hinting = {
      enable = true;
      style = "none";
      autohint = false;
    };
  };
}
