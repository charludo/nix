{ config, pkgs, inputs, ... }:
let
  inherit (inputs.private-settings) domains gsv;
in
{
  imports = [ ./_common.nix ];

  vm = {
    id = 2206;
    name = "SRV-MATRIX";

    hardware.cores = 2;
    hardware.memory = 8192;
    hardware.storage = "4G"; # expand to 128G - not enough ram to do so directly lol

    networking.address = "192.168.20.41";
    networking.gateway = "192.168.20.33";
    networking.prefixLength = 27;
    networking.nameservers = [ "192.168.30.13" ];
    networking.openPorts.tcp = [ config.services.matrix-conduit.settings.global.port ];
  };

  services.matrix-conduit = {
    enable = true;
    settings.global = {
      allow_registration = false;
      server_name = "matrix.${domains.home}";
      allow_federation = false;
      address = "0.0.0.0";
      database_backend = "rocksdb";

      turn_uris = [
        "turn:turn.${domains.blog}:${builtins.toString config.services.coturn.listening-port}?transport=udp"
        "turn:turn.${domains.blog}:${builtins.toString config.services.coturn.listening-port}?transport=tcp"
      ];
      turn_secret = gsv.turnSecret;

      enable_lightning_bolt = false;
      max_request_size = 200000000; # 200MB
    };
  };

  enableNasBackup = true;
  environment.systemPackages = [ pkgs.rsync ];
  systemd = {
    timers."matrix-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "matrix-backup-daily.service";
      };
    };
    services."matrix-backup-daily" = {
      script = ''
        [ "$(stat -f -c %T /media/Backup)" == "smb2" ] && ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.matrix-conduit.settings.global.database_path} /media/Backup/matrix
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  system.stateVersion = "23.11";
}
