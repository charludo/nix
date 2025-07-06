{
  inputs,
  config,
  pkgs,
  private-settings,
  secrets,
  ...
}:
let
  inherit (private-settings) domains;
in
{
  vm = {
    id = 2206;
    name = "SRV-MATRIX";

    hardware.cores = 2;
    hardware.memory = 8192;
    hardware.storage = "128G";

    networking.nameservers = [ "192.168.30.13" ];
    networking.openPorts.tcp = config.services.conduwuit.settings.global.port;
  };

  age.secrets.turn = {
    rekeyFile = secrets.gsv-turn;
    owner = config.services.conduwuit.user;
  };

  services.conduwuit = {
    enable = true;
    package = inputs.conduwuit.outputs.packages."x86_64-linux".default;
    settings.global = rec {
      allow_check_for_updates = false;
      allow_encryption = true;
      allow_registration = false;
      allow_federation = false;
      trusted_servers = [ ];

      server_name = "matrix.${domains.home}";
      address = [ "0.0.0.0" ];
      port = [ 6167 ];

      turn_uris = [
        "turn:turn.${domains.blog}:${builtins.toString config.services.coturn.listening-port}?transport=udp"
        "turn:turn.${domains.blog}:${builtins.toString config.services.coturn.listening-port}?transport=tcp"
      ];
      turn_secret_file = config.age.secrets.turn.path;

      new_user_displayname_suffix = "";
      max_request_size = 1000000000; # 1GB

      well_known = {
        client = "https://${server_name}";
        server = "${server_name}:443";
      };
    };
  };

  nas.backup.enable = true;
  environment.systemPackages =
    let
      restore-conduwuit = pkgs.writeShellApplication {
        name = "restore-conduwuit";
        runtimeInputs = [ pkgs.rsync ];
        text = ''
          ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.conduwuit.user}:${config.services.conduwuit.group} ${config.nas.backup.stateLocation}/matrix/ ${config.services.conduwuit.settings.global.database_path}
        '';
      };
    in
    [
      restore-conduwuit
      pkgs.rsync
    ];
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
        [ "$(stat -f -c %T ${config.nas.backup.stateLocation})" == "smb2" ] && ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.conduwuit.settings.global.database_path} ${config.nas.backup.stateLocation}/matrix
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  system.stateVersion = "23.11";
}
