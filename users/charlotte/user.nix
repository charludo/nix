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
      "nas"
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

  # All this to enable screensharing.
  xdg.portal = {
    enable = true;
    wlr = {
      enable = true;
      settings = {
        screencast = {
          chooser_type = "simple";
          chooser_cmd = "${pkgs.slurp}/bin/slurp -f %o -ro";
        };
      };
    };
    config.common.default = [ "hyprland" ];
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-hyprland
    ];
  };

  services.udisks2.enable = true;

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

  # TEMP
  sops.secrets.zammad = {
    mode = "0444";
    path = "/var/lib/zammad/secret";
  };
  services.zammad = {
    enable = true;
    openPorts = true;
    secretKeyBaseFile = config.sops.secrets.zammad.path;
  };
}
