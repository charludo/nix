{ config, lib, ... }:

with lib;

let
  servicesWithBackup = filterAttrs (_: service: hasAttr "backup" service) config.services;
  allBackups = mapAttrs (_: service: service.backup) servicesWithBackup;
  serviceConfigsForMechanism =
    mechanism:
    filterAttrs (
      _: service:
      service.enable
      && (isNull mechanism || isNull service.mechanisms || builtins.elem mechanism service.mechanisms)
    ) allBackups;

  createService = mechanism: service: {
    "backup-${mechanism.name}-${service.name}" = {
      description = "${mechanism.name} backup job for ${service.name}";
      partOf = [ "backup-${mechanism.name}.service" ];

      path = mechanism.extraPackages;
      startPre = service.preBackup;
      script = mechanism.backupScript service;
      startPost = service.postBackup;

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        ReadWritePaths = [ service.dataDir ];

        type = "oneshot";
        restart = "never";
      };
    };
  };

  createMechanismService = mechanism: {
    "backup-${mechanism.name}" = {
      description = "${mechanism.name} backup job";

      startAt = mechanism.startAt;
      startPre = mechanism.backupCondition;

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;

        type = "oneshot";
        restart = "never";

        CPUSchedulingPolicy = "idle";
        IOSchedulingClass = "idle";
        ProtectSystem = "strict";
      };
    };
  };

  createRestoreScript =
    let
      usedMechanisms = sort (p: q: p.precedence < q.precedence) (
        filter (mechanism: (isNull servic.mechanisms || elem mechanism.name service.mechanisms)) (
          attrsToList cfg.mechanisms
        )
      );
    in
    service:
    pkgs.writeShellApplication {
      name = "restore-${service.name}";
      runtimeInputs = builtins.concatLists (map (mechanism: mechanism.extraPackages) usedMechanisms);
      text = # bash
        ''
          ${service.preRestore}

          CODE=1
          ${map (mechanism: ''
            if [ $CODE == 1 ] && [ ${mechanism.restoreCondition} ];
              ${mechanism.restoreScript service}
              CODE=0
            fi
          '') usedMechanisms}

          ${service.postRestore}

          if [ $CODE==1 ];
            echo "No backups could be restored!"
            exit 1
          fi
        '';
    };

  cfg = config.services.backup;
in
{
  imports = [
    ./services
    ./mechanisms
  ];

  options.services.backup = {
    enable = mkEnableOption (mdDoc "backup & restore");

    autoEnable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Auto-enable backups for supported enabled services
      '';
    };

    notifyScript = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        A bash script to run on failure of a backup procedure
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services = mapAttrs (
      _: mechanism:
      mapAttrs (_: service: (createService mechanism service)) (serviceConfigsForMechanism mechanism.name)
      // (createMechanismService mechanism)
    ) cfg.mechanisms;

    environment.systemPackages = map createRestoreScript (serviceConfigsForMechanism null);
  };
}
