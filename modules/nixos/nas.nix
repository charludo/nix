{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:

with lib;

let
  mountRoot = "/media";
  cfg = config.nas;
in
{
  options.nas = {
    enable = mkEnableOption (mdDoc "enable NAS");
    location = mkOption {
      type = types.str;
      description = "mountpoint for the NAS";
      default = "${mountRoot}/NAS";
    };

    backup.enable = mkEnableOption (mdDoc "enable NAS Backup");
    backup.location = mkOption {
      type = types.str;
      description = "mountpoint for the backup NAS";
      default = "${mountRoot}/Backup";
    };
    backup.stateLocation = mkOption {
      type = types.str;
      description = "the backup NAS folder used for service state backups";
      default = "${mountRoot}/Backup/vm_state";
    };

    extraUsers = mkOption {
      type = types.listOf (types.str);
      description = "additional users who should be allowed to use the NAS";
      default = [ ];
    };

    extraServices = mkOption {
      type = types.listOf (types.str);
      description = "additional services who should be allowed to use the NAS. Useful for dynamicUser services.";
      default = [ ];
    };
  };

  config = mkIf (cfg.enable || cfg.backup.enable) {
    age.secrets.nas.rekeyFile = secrets.nas;
    users.groups.nas.gid = 1111;

    environment.systemPackages = [ pkgs.cifs-utils ];
    boot.supportedFilesystems = [ "cifs" ];

    systemd.tmpfiles.rules = [
      "d ${mountRoot} 0755 root nas -"
    ];

    users.users = genAttrs cfg.extraUsers (_user: {
      extraGroups = [ "nas" ];
    });

    systemd.services = genAttrs cfg.extraServices (_user: {
      serviceConfig.SupplementaryGroups = [ "nas" ];
    });

    systemd.mounts = [
      (mkIf cfg.enable {
        description = "Mount for NAS";
        what = "//192.168.30.11/NAS";
        where = cfg.location;
        type = "cifs";
        options =
          let
            automount_opts = "uid=1000,gid=1111,file_mode=0770,dir_mode=0770,x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
          in
          "${automount_opts},credentials=${config.age.secrets.nas.path}";
        wantedBy = [ "multi-user.target" ];
      })

      (mkIf cfg.backup.enable {
        description = "Mount for Backup";
        what = "//192.168.30.11/Backup";
        where = cfg.backup.location;
        type = "cifs";
        options =
          let
            automount_opts = "uid=1000,gid=1111,file_mode=0770,dir_mode=0770,x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
          in
          "${automount_opts},credentials=${config.age.secrets.nas.path}";
        wantedBy = [ "multi-user.target" ];
      })
    ];

  };
}
