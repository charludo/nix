{ inputs, ... }:
let
  inherit (inputs.private-settings) gsv;
in
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
      proxmox = { hostname = "192.168.30.15"; user = "root"; };
      gsv = { hostname = gsv.ip; user = gsv.user; port = gsv.port; };
      gsv-boot = { hostname = gsv.ip; user = gsv.user; port = gsv.port-boot; };
      duesseldorf = { hostname = "78.31.66.125"; user = "charlotte"; };
      "* !duesseldorf !proxmox !gsv !gsv-boot" = { user = "paki"; };
      "jellyfin torrenter paperless pdf blocky proxmos".extraOptions = {
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
