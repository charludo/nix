{ config, inputs, ... }: {
  imports = [ ./_common.nix ];

  vm = {
    id = 2205;
    name = "SRV-IMMICH";

    hardware.cores = 4;
    hardware.memory = 16384;
    hardware.storage = "32G";
  };

  users.users."${config.services.immich.user}" = {
    uid = 1111;
    extraGroups = [ "nas" ];
  };
  users.groups."${config.services.immich.group}".gid = 1111;

  services.immich = {
    enable = true;

    host = "0.0.0.0";
    port = 2283;
    openFirewall = true;

    mediaLocation = "/media/Backup/immich";
    settings.server.externalDomain = "https://pictures.${inputs.private-settings.domains.home}";

    # https://github.com/immich-app/immich/discussions/4758#discussioncomment-7441670
    environment.UV_USE_IO_URING = "0";
  };

  systemd.mounts = [{
    description = "Mount for Backup - Immich edition";
    what = "//192.168.30.11/Backup";
    where = "/media/Backup";
    type = "cifs";
    options =
      let
        automount_opts = "uid=1111,gid=1111,file_mode=0770,dir_mode=0770,x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
      in
      "${automount_opts},credentials=${config.sops.secrets.nas.path}";
    wantedBy = [ "multi-user.target" ];
  }];

  # environment.systemPackages = [ paperless-init ];

  # systemd = {
  #   timers."paperless-backup-daily" = {
  #     wantedBy = [ "timers.target" ];
  #     timerConfig = {
  #       OnCalendar = "daily";
  #       Persistent = true;
  #       Unit = "paperless-backup-daily.service";
  #     };
  #   };
  #   timers."paperless-backup-monthly" = {
  #     wantedBy = [ "timers.target" ];
  #     timerConfig = {
  #       OnCalendar = "monthly";
  #       Persistent = true;
  #       Unit = "paperless-backup-monthly.service";
  #     };
  #   };
  #
  #   services."paperless-backup-daily" = {
  #     script = ''
  #       /var/lib/paperless/paperless-manage document_exporter "${backupDirDaily}" -p -d
  #       /var/lib/paperless/paperless-manage document_create_classifier
  #     '';
  #     serviceConfig = {
  #       Type = "oneshot";
  #       User = "root";
  #     };
  #   };
  #   services."paperless-backup-monthly" = {
  #     script = ''
  #       /var/lib/paperless/paperless-manage document_exporter "${backupDirMonthly}" -z
  #     '';
  #     serviceConfig = {
  #       Type = "oneshot";
  #       User = "root";
  #     };
  #   };
  # };

  system.stateVersion = "23.11";
}
