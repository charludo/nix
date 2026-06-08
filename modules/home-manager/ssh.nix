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
      settings = {
        proxmox-gpu = {
          HostName = "192.168.30.14";
          User = "root";
        };
        proxmox = {
          HostName = "192.168.30.15";
          User = "root";
        };
        proxmox2 = {
          HostName = "192.168.30.16";
          User = "root";
        };
        home-assistant = {
          HostName = "192.168.24.27";
          User = "root";
        };

        "${lib.concatStringsSep " " (builtins.attrNames lib.helpers.allVMSSHConfigs)}" = {
          User = "paki";
        };
        "proxmox home-assistant ${lib.concatStringsSep " " (builtins.attrNames lib.helpers.allVMSSHConfigs)}" =
          {
            StrictHostKeyChecking = "no";
            LogLevel = "quiet";
          };
        "*" = {
          AddKeysToAgent = "yes";
          IdentityFile = [ "~/.ssh/id_ed25519" ];
          IdentitiesOnly = true;
          SetEnv = {
            TERM = "xterm-256color";
            COLORTERM = "truecolor";
          };

          ForwardAgent = false;
          Compression = false;
          ServerAliveInterval = 0;
          ServerAliveCountMax = 3;
          HashKnownHosts = false;
          UserKnownHostsFile = "~/.ssh/known_hosts";
          ControlMaster = "no";
          ControlPath = "~/.ssh/master-%r@%n:%p";
          ControlPersist = "no";
        };
      }
      // lib.helpers.allVMSSHConfigs;
    };
  };
}
