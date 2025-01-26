{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  serviceConfigsForMechanism =
    mechanism:
    filterAttrs (
      _: service:
      service.enable
      && (isNull mechanism || isNull service.mechanisms || builtins.elem mechanism service.mechanisms)
    ) cfg.services;

  createService = mechanismName: mechanism: serviceName: service: {
    "backup-${mechanismName}-${serviceName}" = {
      description = "${mechanismName} backup job for ${serviceName}";
      partOf = [ "backup-${mechanismName}.service" ];

      path = mechanism.extraPackages;
      preStart = service.preBackup;
      script = mechanism.backupScript service;
      postStop = service.postBackup;

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        ReadWritePaths = [ service.dataDir ];

        type = "oneshot";
        restart = "never";
      };
    };
  };

  createMechanismService = mechanismName: mechanism: {
    "backup-${mechanismName}" = {
      description = "${mechanismName} backup job";

      startAt = mechanism.startAt;
      preStart = mechanism.backupCondition;

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
    serviceName: service:
    let
      usedMechanisms = sort (p: q: p.precedence < q.precedence) (
        filter (mechanism: (isNull service.mechanisms || elem mechanism.name service.mechanisms)) (
          builtins.attrValues cfg.mechanisms
        )
      );
    in
    pkgs.writeShellApplication {
      name = "restore-${serviceName}";
      runtimeInputs = builtins.concatLists (map (mechanism: mechanism.extraPackages) usedMechanisms);
      text = # bash
        ''
          ${service.preRestore}

          CODE=1
          ${builtins.toString (
            map (mechanism: ''
              if [ $CODE == 1 ] && ${mechanism.restoreCondition};
                ${mechanism.restoreScript service}
                CODE=0
              fi
            '') usedMechanisms
          )}

          ${service.postRestore}

          if [ $CODE == 1 ];
            echo "No backups could be restored!"
            exit 1
          fi
        '';
    };

  cfg = config.backup;
in
{
  imports = [
    ./services
    ./mechanisms
  ];

  options.backup = {
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
    systemd.services = concatMapAttrs (
      mechanismName: mechanism:
      (
        concatMapAttrs (serviceName: service: (createService mechanismName mechanism serviceName service)) (
          serviceConfigsForMechanism mechanismName
        )
        // (createMechanismService mechanismName mechanism)
      )
    ) cfg.mechanisms;

    environment.systemPackages = builtins.attrValues (
      mapAttrs (serviceName: service: createRestoreScript serviceName service) (
        serviceConfigsForMechanism null
      )
    );
  };
}
