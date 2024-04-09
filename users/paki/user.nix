{ pkgs, config, lib, ... }:
let ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  users.users.paki = {
    isNormalUser = true;
    shell = pkgs.bash;
    extraGroups = [
      "wheel"
      "networkmanager"
    ] ++ ifTheyExist [
      "docker"
      "git"
    ];

    openssh.authorizedKeys.keys = [ (builtins.readFile ../charlotte/ssh.pub) (builtins.readFile ../marie/ssh.pub) ];
    packages = with pkgs; [ git dig ];
  };

  security.sudo.extraRules = [
    {
      users = [ "paki" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" "SETENV" ];
        }
      ];
    }
  ];

  environment.shells = with pkgs; [ bash ];
}
