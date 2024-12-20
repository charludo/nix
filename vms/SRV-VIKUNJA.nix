{ config, inputs, pkgs, ... }:
let
  inherit (inputs.private-settings) domains;
in
{
  imports = [ ./_common.nix ];

  vm = {
    id = 2209;
    name = "SRV-VIKUNJA";

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "16G";

    networking.openPorts.tcp = [ config.services.vikunja.port ];
  };

  services.vikunja = {
    enable = true;
    frontendScheme = "https";
    frontendHostname = "planning.${domains.home}";
    settings.service.enableregistration = false;
  };

  enableNas = true;
  enableNasBackup = true;

  systemd = {
    timers."vikunja-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "vikunja-backup-daily.service";
      };
    };
    services."vikunja-backup-daily" = {
      script = ''
        [ "$(stat -f -c %T /media/Backup)" != "smb2" ] && exit 1
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace /var/lib/vikunja/ /media/Backup/vikunja
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  environment.systemPackages =
    let
      vikunja-init = pkgs.writeShellApplication {
        name = "vikunja-init";
        runtimeInputs = [ pkgs.rsync ];
        text = ''
          ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace /media/Backup/vikunja/ /var/lib/vikunja
        '';
      };
    in
    [ vikunja-init pkgs.rsync ];

  system.stateVersion = "23.11";
}
