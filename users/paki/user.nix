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
  age.secrets.paki-password.rekeyFile = secrets.paki-password;

  users.users.paki = {
    isNormalUser = true;
    shell = pkgs.bash;
    extraGroups =
      [
        "wheel"
        "networkmanager"
        "nas"
      ]
      ++ ifTheyExist [
        "docker"
        "git"
      ];

    hashedPasswordFile = config.age.secrets.paki-password.path;
    openssh.authorizedKeys.keys = [
      (builtins.readFile ../charlotte/zakalwe_ssh.pub)
      (builtins.readFile ../charlotte/perostek_ssh.pub)
      (builtins.readFile ../charlotte/diziet_ssh.pub)
      (builtins.readFile ../charlotte/ssh.pub)
      (builtins.readFile ../marie/ssh.pub)
    ];
    packages = with pkgs; [
      git
      dig
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ "paki" ];
      commands = [
        {
          command = "ALL";
          options = [
            "NOPASSWD"
            "SETENV"
          ];
        }
      ];
    }
  ];

  environment.shells = with pkgs; [ bash ];
}
