{ config, pkgs, secrets, ... }: {
  imports = [ ./_common.nix ];

  vm = {
    id = 2208;
    name = "SRV-KAVITA";

    hardware.cores = 4;
    hardware.memory = 8192;
    hardware.storage = "16G";

    networking.nameservers = [ "1.1.1.1" ];
    networking.openPorts.tcp = [ config.services.kavita.settings.Port ];
  };

  sops.secrets.kavita-token = { sopsFile = secrets.kavita; };
  services.kavita = {
    enable = true;
    tokenKeyFile = config.sops.secrets.kavita-token.path;
    settings.IpAddresses = "0.0.0.0";
  };

  enableNas = true;
  enableNasBackup = true;
  users.users."${config.services.kavita.user}".extraGroups = [ "nas" ];

  systemd = {
    timers."kavita-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "kavita-backup-daily.service";
      };
    };
    services."kavita-backup-daily" = {
      script = ''
        [ "$(stat -f -c %T /media/NAS)" != "smb2" ] && exit 1
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace --chown=${config.services.kavita.user}:* ${config.services.kavita.dataDir}/ /media/Backup/kavita
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  environment.systemPackages =
    let
      kavita-init = pkgs.writeShellApplication {
        name = "kavita-init";
        runtimeInputs = [ pkgs.rsync ];
        text = ''
          ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace --chown=${config.services.kavita.user}:* /media/Backup/kavita/ ${config.services.kavita.dataDir}
        '';
      };
    in
    [ kavita-init pkgs.rsync ];

  system.stateVersion = "23.11";
}
