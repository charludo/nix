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
      (builtins.readFile ../charlotte/zakalwe_ssh.pub)
      (builtins.readFile ../charlotte/perostek_ssh.pub)
      (builtins.readFile ../charlotte/diziet_ssh.pub)
      (builtins.readFile ../charlotte/ssh.pub)
      (builtins.readFile ./ssh.pub)
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
