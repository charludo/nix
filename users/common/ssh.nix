{ lib, outputs, ... }:
let
  toLowercaseKeys =
    attrs:
    lib.listToAttrs (
      lib.mapAttrsToList (key: value: {
        name = lib.toLower (lib.replaceStrings [ "SRV-" ] [ "" ] key);
        value = value;
      }) attrs
    );
  vms = toLowercaseKeys (
    lib.filterAttrs (_: v: v.hostname != null) (
      builtins.mapAttrs (name: _: {
        hostname =
          if lib.pathExists ../../vms/keys/ssh_host_${name}_ed25519_key.pub then
            let
              interfaces = outputs.nixosConfigurations.${name}.config.networking.interfaces;
              iface = lib.findFirst (i: interfaces ? ${i}) null [
                "ens18"
                "enp6s18"
              ];
            in
            if iface != null then (builtins.head interfaces.${iface}.ipv4.addresses).address else null
          else
            null;
      }) outputs.nixosConfigurations
    )
  );
in
{
  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
    matchBlocks = {
      proxmox-gpu = {
        hostname = "192.168.30.14";
        user = "root";
      };
      proxmox = {
        hostname = "192.168.30.15";
        user = "root";
      };
      proxmox2 = {
        hostname = "192.168.30.16";
        user = "root";
      };
      home-assistant = {
        hostname = "192.168.10.27";
        user = "root";
      };

      "* !proxmox !proxmox2 !proxmox-gpu !home-assistant !gsv !gsv-boot" = {
        user = "paki";
      };
      "proxmox home-assistant ${lib.concatStringsSep " " (builtins.attrNames vms)}".extraOptions = {
        "StrictHostKeyChecking" = "no";
        "LogLevel" = "quiet";
      };
      "*" = {
        identityFile = [
          "~/.ssh/id_yubikey"
          "~/.ssh/id_ed25519"
        ];
        identitiesOnly = true;
        setEnv = {
          TERM = "xterm-256color";
          COLORTERM = "truecolor";
        };
      };
    } // vms;
  };
}
