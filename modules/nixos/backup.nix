{ config, lib, pkgs, ... }:

with lib;

let
in
{
  options.services.backup = {
    enable = mkEnableOption (lib.mdDoc "backup & restore");

    autoEnable = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc ''
        Auto-enable backups for supported enabled services
      '';
    };

    backupCondition = mkOption {
      type = types.str;
      default = "";
      description = lib.mkDoc ''
        A bash expression which, if it returns a non-zero exit code, prevents backups from being created.
      '';
      example = ''
        "$(stat -f -c %T /path/to/NAS)" == "smb2"
      '';
    };

    backupMechanism = mkOption {
      type = types.functionTo types.str;
      description = lib.mkDoc ''
        A nix expression which generates the bash script used to create the backups.
        Receives a single argument of type (listOf set), where each set contains a `from` key and a `to` key,
        derived from the services for which backups are enabled.
      '';
      example = services: builtins.map (service: "${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${service.from}/ ${service.to}") services;
    };

    restoreMechanism = mkOption {
      type = types.functionTo types.str;
      description = lib.mkDoc ''
        A nix expression which generates the bash script used to restore backups.
        Receives a single argument of type (listOf set), where each set contains a `from` key and a `to` key, as well as the user and group for that service,
        derived from the services for which backups (and, by extension, restores) are enabled.
      '';
      example = services: builtins.map (service: "${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${service.user}:${service.group} ${service.to}/ ${service.from}") services;
    };

    backupDir = mkOption {
      type = types.str;
      description = lib.mkDoc ''
        Path to the root dir where backups should be stored.
      '';
      example = "/media/Backups";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    systemd.services.qbittorrent = {
      # based on the plex.nix service module and
      # https://github.com/qbittorrent/qBittorrent/blob/master/dist/unix/systemd/qbittorrent-nox%40.service.in
      description = "qBittorrent-nox service";
      documentation = [ "man:qbittorrent-nox(1)" ];
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;

        # Run the pre-start script with full permissions (the "!" prefix) so it
        # can create the data directory if necessary.
        ExecStartPre =
          let
            preStartScript = pkgs.writeScript "qbittorrent-run-prestart" ''
              #!${pkgs.bash}/bin/bash

              # Create data directory if it doesn't exist
              if ! test -d "$QBT_PROFILE"; then
                echo "Creating initial qBittorrent data directory in: $QBT_PROFILE"
                install -d -m 0755 -o "${cfg.user}" -g "${cfg.group}" "$QBT_PROFILE"
              fi
            '';
          in
          "!${preStartScript}";

        #ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox";
        ExecStart = "${cfg.package}/bin/qbittorrent-nox";
        # To prevent "Quit & shutdown daemon" from working; we want systemd to
        # manage it!
        #Restart = "on-success";
        #UMask = "0002";
        #LimitNOFILE = cfg.openFilesLimit;
      };

      environment = {
        QBT_PROFILE = cfg.dataDir;
        QBT_WEBUI_PORT = toString cfg.port;
      };
    };

    users.users = mkIf (cfg.user == "qbittorrent") {
      qbittorrent = {
        group = cfg.group;
        uid = UID;
      };
    };

    users.groups = mkIf (cfg.group == "qbittorrent") {
      qbittorrent = { gid = GID; };
    };
  };
}
