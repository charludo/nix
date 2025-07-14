{
  pkgs,
  config,
  ...
}:
let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  users.users.marie = {
    isNormalUser = true;
    shell = pkgs.bash;
    initialPassword = "";
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

    openssh.authorizedKeys.keys = [
      (builtins.readFile ../charlotte/keys/zakalwe_ssh.pub)
      (builtins.readFile ../charlotte/keys/perostek_ssh.pub)
      (builtins.readFile ../charlotte/keys/diziet_ssh.pub)
      (builtins.readFile ../charlotte/keys/ssh.pub)
      (builtins.readFile ./keys/ssh.pub)
    ];
    packages = with pkgs; [
      git
      dig
      nano
      neovim
      tcpdump
      nettools
      traceroute
      nmap
      wirelesstools
    ];
  };
  users.groups.marie.gid = 1000;

  home-manager.users.marie = import ./home/${config.networking.hostName}.nix;

  environment.shells = with pkgs; [ bash ];
}
