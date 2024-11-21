{ config, lib, outputs, ... }:
let
  transform = attrs: { hostname = builtins.toString attrs.address; };
in
{
  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
    matchBlocks = {
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
    } // lib.filterAttrs
      (_: v: v.hostname != null)
      (builtins.mapAttrs
        (name: _: {
          hostname = (if (lib.pathExists ../../vms/keys/ssh_host_${name}_ed25519_key.pub) then ((builtins.head outputs.nixosConfigurations.${name}.config.networking.interfaces.ens18.ipv4.addresses).address) else null);
        })
        outputs.nixosConfigurations);
  };
}
