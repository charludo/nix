{ config, lib, ... }:
let
  cfg = config.ssh;
in
{
  options.ssh.enable = lib.mkEnableOption "custom SSH config";

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
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
        "proxmox home-assistant ${lib.concatStringsSep " " (builtins.attrNames lib.helpers.allVMSSHConfigs)}".extraOptions =
          {
            "StrictHostKeyChecking" = "no";
            "LogLevel" = "quiet";
          };
        "*" = {
          addKeysToAgent = "yes";
          identityFile = [ "~/.ssh/id_ed25519" ];
          identitiesOnly = true;
          setEnv = {
            TERM = "xterm-256color";
            COLORTERM = "truecolor";
          };

          forwardAgent = false;
          compression = false;
          serverAliveInterval = 0;
          serverAliveCountMax = 3;
          hashKnownHosts = false;
          userKnownHostsFile = "~/.ssh/known_hosts";
          controlMaster = "no";
          controlPath = "~/.ssh/master-%r@%n:%p";
          controlPersist = "no";
        };
      }
      // lib.helpers.allVMSSHConfigs;
    };
  };
}
