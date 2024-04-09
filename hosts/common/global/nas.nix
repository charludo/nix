{ pkgs, config, lib, ... }:
{
  sops.secrets.nas = lib.mkIf (config.enableNas or config.enableNasBackup) { };

  environment.systemPackages = lib.mkIf (config.enableNas or config.enableNasBackup) [ pkgs.cifs-utils ];

  fileSystems."/media/NAS" = lib.mkIf config.enableNas {
    device = "//192.168.30.11/NAS";
    fsType = "cifs";
    options =
      let
        automount_opts = "uid=1000,x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
      in
      [ "${automount_opts},credentials=${config.sops.secrets.nas.path}" ];
  };

  fileSystems."/media/Backup" = lib.mkIf config.enableNasBackup {
    device = "//192.168.30.11/Backup";
    fsType = "cifs";
    options =
      let
        automount_opts = "uid=1000,x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
      in
      [ "${automount_opts},credentials=${config.sops.secrets.nas.path}" ];
  };
}
