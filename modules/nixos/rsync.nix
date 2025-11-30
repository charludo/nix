{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.rsync;
in
{
  options.rsync = lib.mkOption {
    type =
      with lib.types;
      attrsOf (submodule ({
        options = {
          tasks = lib.mkOption {
            type = listOf (submodule ({
              options = {
                from = lib.mkOption {
                  type = types.str;
                  description = "origin of the backup";
                };
                to = lib.mkOption {
                  type = types.str;
                  description = "destination of the backup";
                };
                chown = lib.mkOption {
                  type = nullOr str;
                  description = "`owner:group` of the files. only used in the restore script. `--chown` is omitted if this is null";
                  default = null;
                };
                extraFlags = lib.mkOption {
                  type = str;
                  description = "extra flags to pass to rsync. Will also be set in the restore script and passed after the global `extraFlags`";
                  default = "";
                };
                prefixCommand = lib.mkOption {
                  type = str;
                  description = "extra command that is prefixed to the entire rsync command";
                  default = "";
                  example = ''
                    find /some/dir -maxdepth 0 -type d -exec
                  '';
                };
                suffixCommand = lib.mkOption {
                  type = str;
                  description = "extra command that is suffixed to the entire rsync command, e.g. to terminate a prefixed exec";
                  default = "";
                  example = ''
                    \\;
                  '';
                };
              };
            }));
            description = "a list of `{ from, to }` tuples describing backup task origins and destinations";
          };
          extraFlags = lib.mkOption {
            type = str;
            description = "extra flags to pass to rsync. Will also be set in the restore script";
            default = "";
          };
          timerConfig = lib.mkOption {
            type = anything;
            description = "a systemd timer configuration. See `systemd.timers.<name>.timerConfig` for all options";
            default = {
              OnCalendar = "daily";
              Persistent = true;
              RandomizedDelaySec = "3h";
            };
          };
          requires = lib.mkOption {
            type = listOf str;
            description = "a list of mounts that must be available for the backup to be started";
            default = [
              "media-Backup.mount"
            ];
          };
          restore = lib.mkOption {
            type = bool;
            description = "whether to generate a restore script";
            default = true;
          };
        };
      }));
    default = { };
    description = "an arbitrary number of rsync tasks";
  };

  config = mkIf (cfg != { }) {
    systemd.services = (
      lib.mapAttrs' (name: rsync: {
        name = "rsync-task-${name}";
        value = {
          inherit (rsync) requires;
          script = lib.concatStringsSep "\n" (
            lib.map (
              task:
              let
                from = lib.removeSuffix "/" (lib.trim task.from);
                to = lib.removeSuffix "/" (lib.trim task.to);
              in
              # bash
              ''
                ${task.prefixCommand} ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${rsync.extraFlags} ${task.extraFlags} "${from}/" "${to}" ${task.suffixCommand}
              ''
            ) rsync.tasks
          );
          serviceConfig = {
            Type = "oneshot";
            User = "root";
          };
        };
      }) cfg
    );

    systemd.timers = (
      lib.mapAttrs' (name: rsync: {
        name = "rsync-task-${name}";
        value = {
          inherit (rsync) timerConfig;
          wantedBy = [ "timers.target" ];
        };
      }) cfg
    );

    environment.systemPackages =
      lib.concatLists (
        lib.mapAttrsToList (name: rsync: [
          (pkgs.writeShellApplication {
            name = "rsync-restore-${name}";
            runtimeInputs = [ pkgs.rsync ];
            text = lib.concatStringsSep "\n" (
              lib.map (
                task:
                let
                  from = lib.removeSuffix "/" (lib.trim task.from);
                  to = lib.removeSuffix "/" (lib.trim task.to);
                  chown = if task.chown != null then "--chown ${task.chown}" else "";
                in
                # bash
                ''
                  ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace ${chown} ${rsync.extraFlags} ${task.extraFlags} "${to}/" "${from}"
                ''
              ) rsync.tasks
            );
          })
        ]) (filterAttrs (_: rsync: rsync.restore == true) cfg)
      )
      ++ [
        pkgs.rsync
      ];
  };
}
