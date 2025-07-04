{
  config,
  pkgs,
  secrets,
  ...
}:
{
  vm = {
    id = 2219;
    name = "SRV-ANKI";

    hardware.cores = 1;
    hardware.memory = 1024;
    hardware.storage = "8G";
  };

  services.anki-sync-server = {
    enable = true;
    address = "0.0.0.0";
    port = 8080;
    openFirewall = true;
    users = [
      {
        username = "charlotte";
        passwordFile = config.age.secrets.anki-charlotte.path;
      }
      {
        username = "marie";
        passwordFile = config.age.secrets.anki-marie.path;
      }
    ];
  };
  age.secrets.anki-charlotte.rekeyFile = secrets.charlotte-anki;
  age.secrets.anki-marie.rekeyFile = secrets.marie-anki;

  nas.backup.enable = true;
  systemd = {
    timers."anki-sync-server-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "anki-sync-server-backup-daily.service";
      };
    };
    services."anki-sync-server-backup-daily" = {
      script = ''
        [ "$(stat -f -c %T ${config.nas.backup.location})" == "smb2" ] && ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace /var/lib/anki-sync-server/ ${config.nas.backup.location}/anki-sync-server
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  environment.systemPackages =
    let
      restore-anki-sync-server = pkgs.writeShellApplication {
        name = "restore-anki-sync-server";
        runtimeInputs = [ pkgs.rsync ];
        text = ''
          ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace  ${config.nas.backup.location}/anki-sync-server/ /var/lib/anki-sync-server
        '';
      };
    in
    [
      restore-anki-sync-server
      pkgs.rsync
    ];

  system.stateVersion = "23.11";
}
