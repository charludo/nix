{
  pkgs,
  config,
  secrets,
  ...
}:
let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  sops.secrets.charlotte-password = {
    neededForUsers = true;
    sopsFile = secrets.charlotte;
  };

  users.users.charlotte = {
    isNormalUser = true;
    shell = pkgs.fish;

    uid = 1000;
    group = "charlotte";
    extraGroups =
      [
        "wheel"
        "video"
        "audio"
        "networkmanager"
        "nas"
      ]
      ++ ifTheyExist [
        "docker"
        "git"
      ];

    openssh.authorizedKeys.keys = [ (builtins.readFile ./ssh.pub) ];
    hashedPasswordFile = config.sops.secrets.charlotte-password.path;
    packages = with pkgs; [
      home-manager
      git
    ];
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
  environment.shells = with pkgs; [
    fish
    bash
  ];
}
