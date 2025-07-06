{ config, lib, ... }:
let
  cfg = config.ssh;
in
{
  options.ssh.enable = lib.mkEnableOption "enable custom SSH config";

  config = lib.mkIf cfg.enable {
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
          hostname = "192.168.24.27";
          user = "root";
        };

        "* !proxmox !proxmox2 !proxmox-gpu !home-assistant !gsv !gsv-boot" = {
          user = "paki";
        };
        "proxmox home-assistant ${lib.concatStringsSep " " (builtins.attrNames lib.helpers.allVMs)}".extraOptions =
          {
            "StrictHostKeyChecking" = "no";
            "LogLevel" = "quiet";
          };
        "*" = {
          identityFile = [ "~/.ssh/id_ed25519" ];
          identitiesOnly = true;
          setEnv = {
            TERM = "xterm-256color";
            COLORTERM = "truecolor";
          };
        };
      } // lib.helpers.allVMs;
    };
  };
}
