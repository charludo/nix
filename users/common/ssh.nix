{
  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
    matchBlocks = {
      jellyfin = { hostname = "192.168.20.36"; };
      torrenter = { hostname = "192.168.20.20"; };
      paperless = { hostname = "192.168.20.37"; };
      pdf = { hostname = "192.168.20.38"; };
      wastebin = { hostname = "192.168.20.39"; };
      blocky = { hostname = "192.168.30.13"; };
      cloudsync = { hostname = "192.168.30.31"; };
      git = { hostname = "192.168.30.30"; };
      matrix = { hostname = "192.168.20.41"; };
      cl-nix = { hostname = "192.168.30.95"; };
      proxmox = { hostname = "192.168.30.15"; user = "root"; };
      home-assistant = { hostname = "192.168.10.27"; user = "root"; };
      "* !proxmox !home-assistant !gsv !gsv-boot" = { user = "paki"; };
      "jellyfin torrenter paperless pdf blocky proxmos wastebin cloudsync git cl-nix".extraOptions = {
        "StrictHostKeyChecking" = "no";
        "LogLevel" = "quiet";
      };
      "*" = {
        identityFile = "~/.ssh/id_ed25519";
        identitiesOnly = true;
      };
    };
  };
}
