{
  config,
  pkgs,
  ...
}:
{
  vm = {
    id = 2216;
    name = "SRV-PINCHFLAT";

    hardware.cores = 2;
    hardware.memory = 8192;
    hardware.storage = "16G";
  };

  services.pinchflat = {
    enable = true;
    openFirewall = true;
    selfhosted = true;
    mediaDir = config.nas.location;
  };

  nas.enable = true;
  nas.backup.enable = true;
  nas.extraUsers = [ config.services.pinchflat.user ];

  environment.systemPackages =
    let
      restore-pinchflat = pkgs.writeShellApplication {
        name = "restore-pinchflat";
        runtimeInputs = [ pkgs.rsync ];
        text = ''
          ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown pinchflat:pinchflat ${config.nas.backup.location}/pinchflat/ /var/lib/pinchflat
        '';
      };
    in
    [ restore-pinchflat ];

  systemd = {
    services.pinchflat.after = [
      "media-NAS.mount"
    ];
    services.pinchflat.partOf = [
      "media-NAS.mount"
    ];

    timers."pinchflat-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "pinchflat-backup-daily.service";
      };
    };
    services."pinchflat-backup-daily" = {
      script = ''
        [ "$(stat -f -c %T ${config.nas.backup.location})" != "smb2" ] && exit 1
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace /var/lib/pinchflat/ ${config.nas.backup.location}/pinchflat
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  system.stateVersion = "23.11";
}
