{
  config,
  lib,
  pkgs,
  private-settings,
  ...
}:
let
  cfg = config.borg;
in
{
  options.borg = lib.mkOption {
    type =
      with lib.types;
      attrsOf (submodule ({
        options = {
          paths = lib.mkOption {
            type = listOf str;
            description = "folders and files to backup";
          };
          exclude = lib.mkOption {
            type = listOf str;
            description = "folders and files to exclude in backups";
            default = [
              "'**/node_modules'"
              "'**/.venv'"
              "'**/.cache'"
            ];
          };
          startAt = lib.mkOption {
            type = either str (listOf str);
            description = "time to start the backup at. Set to `[ ]` for no automatic runs";
            default = "02:15";
          };
          remote = lib.mkOption {
            type = str;
            description = "the url of the remote borg repo";
            default = private-settings.domains.cloudsync;
            defaultText = "(populated from git submodule)";
          };
          port = lib.mkOption {
            type = int;
            description = "SSH port used by the borg machine";
            default = 23;
          };
          secrets.password = lib.mkOption {
            type = path;
            description = "path to a secret containing the password used to encrypt the repokey. Agenix secret created automatically";
          };
          secrets.sshKey = lib.mkOption {
            type = path;
            description = "path to a secret containing the private SSH key used for authentication with the borg machine. Agenix secret created automatically";
          };
        };
      }));
    default = { };
    description = "an arbitrary number of borgbackup instances";
  };

  config = {
    age.secrets = (
      lib.concatMapAttrs (name: borg: {
        "borg-password-${name}".rekeyFile = borg.secrets.password;
        "borg-ssh-key-${name}".rekeyFile = borg.secrets.sshKey;
      }) cfg
    );

    services.borgbackup.jobs = (
      builtins.mapAttrs (name: borg: {
        inherit (borg) paths exclude startAt;

        repo = "${borg.remote}:${name}";
        encryption = {
          mode = "repokey";
          passCommand = "cat ${config.age.secrets."borg-password-${name}".path}";
        };
        environment = {
          BORG_RSH = "ssh -p ${builtins.toString borg.port} -i ${
            config.age.secrets."borg-ssh-key-${name}".path
          }";
        };
        compression = "auto,lzma";
        doInit = false; # instead, provide script below
      }) cfg
    );

    environment.systemPackages = lib.concatLists (
      lib.mapAttrsToList (
        name: borg:
        let
          repo = "ssh://${borg.remote}:${builtins.toString borg.port}/./${name}";
          environment = ''
            export BORG_PASSCOMMAND="${config.services.borgbackup.jobs."${name}".encryption.passCommand}"
            export BORG_REPO="${config.services.borgbackup.jobs."${name}".repo}"
            export BORG_RSH="${config.services.borgbackup.jobs."${name}".environment.BORG_RSH}"
          '';
        in
        [
          (pkgs.writeShellApplication {
            name = "borg-init-${name}";
            runtimeInputs = [ pkgs.borgbackup ];
            text =
              environment
              # bash
              + ''
                ${pkgs.borgbackup}/bin/borg init --encryption=repokey --remote-path=${repo}
                ${pkgs.borgbackup}/bin/borg key export ${repo}
              '';
          })
          (pkgs.writeShellApplication {
            name = "borg-mount-${name}";
            runtimeInputs = [ pkgs.borgbackup ];
            text =
              environment
              # bash
              + ''
                mkdir -p "/mnt/borg-${name}"
                ${pkgs.borgbackup}/bin/borg mount ${repo} "/mnt/borg-${name}"
                echo "mounted to /mnt/borg-${name}"
              '';
          })
          (pkgs.writeShellApplication {
            name = "borg-umount-${name}";
            runtimeInputs = [ pkgs.borgbackup ];
            text = # bash
              ''
                ${pkgs.borgbackup}/bin/borg umount "/mnt/borg-${name}"
                echo "un-mounted /mnt/borg-${name}"
              '';
          })
          (pkgs.writeShellApplication {
            name = "borg-check-${name}";
            runtimeInputs = [ pkgs.borgbackup ];
            text =
              environment
              # bash
              + ''
                ${pkgs.borgbackup}/bin/borg check ${repo}
              '';
          })
        ]
      ) cfg
    );
  };
}
