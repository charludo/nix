{ pkgs, config, lib, ... }:
{
  sops.secrets.nas = lib.mkIf (config.enableNas or config.enableNasBackup) { };
  users.groups.nas.gid = lib.mkIf (config.enableNas or config.enableNasBackup) 1111;

  environment.systemPackages = [ pkgs.cifs-utils ];
  boot.supportedFilesystems = [ "cifs" ];

  systemd.tmpfiles.rules = [
    "d /media 0755 root nas -"
  ];

  systemd.mounts = [
    (lib.mkIf config.enableNas {
      description = "Mount for NAS";
      what = "//192.168.30.11/NAS";
      where = "/media/NAS";
      type = "cifs";
      options =
        let
          automount_opts = "uid=1000,gid=1111,file_mode=0770,dir_mode=0770,x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
        in
        "${automount_opts},credentials=${config.sops.secrets.nas.path}";
      wantedBy = [ "multi-user.target" ];
    })

    (lib.mkIf config.enableNasBackup {
      description = "Mount for Backup";
      what = "//192.168.30.11/Backup";
      where = "/media/Backup";
      type = "cifs";
      options =
        let
          automount_opts = "uid=1000,gid=1111,file_mode=0770,dir_mode=0770,x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
        in
        "${automount_opts},credentials=${config.sops.secrets.nas.path}";
      wantedBy = [ "multi-user.target" ];
    })
  ];
}
