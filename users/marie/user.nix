{
  inputs,
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

  home-manager.sharedModules = [ inputs.plasma-manager.homeManagerModules.plasma-manager ];
  home-manager.users.marie = import ./home/CL-NIX.nix;

  environment.shells = with pkgs; [ bash ];
}
