{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      jellyfin = { hostname = "192.168.20.36"; };
      torrenter = { hostname = "192.168.20.20"; };
      paperless = { hostname = "192.168.20.37"; };
      pihole = { hostname = "192.168.30.13"; };
      proxmox = { hostname = "192.168.10.15"; user = "root"; };
      duesseldorf = { hostname = "78.31.66.125"; user = "charlotte"; };
      "* !duesseldorf !proxmox" = { user = "paki"; };
    };
  };
}
