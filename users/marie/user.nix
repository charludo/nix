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
    initialPassword = "";
    extraGroups = [
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
      tcpdump
      nettools
      traceroute
      nmap
      wirelesstools

      ours.nvim
    ];
  };
  users.groups.marie.gid = 1000;

  home-manager.users.marie = import ./home/${config.networking.hostName}.nix;
}
