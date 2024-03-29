{ pkgs, config, ... }:
{
  sops.secrets.nas = { };

  environment.systemPackages = [ pkgs.cifs-utils ];

  fileSystems."/media/NAS" = {
    device = "//192.168.30.11/NAS";
    fsType = "cifs";
    options =
      let
        automount_opts = "uid=1000,x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
      in
      [ "${automount_opts},credentials=${config.sops.secrets.nas.path}" ];
  };

  fileSystems."/media/Backup" = {
    device = "//192.168.30.11/Backup";
    fsType = "cifs";
    options =
      let
        automount_opts = "uid=1000,x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
      in
      [ "${automount_opts},credentials=${config.sops.secrets.nas.path}" ];
  };
}
