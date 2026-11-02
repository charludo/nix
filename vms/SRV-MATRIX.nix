{
  config,
  lib,
  private-settings,
  secrets,
  outputs,
  ...
}:
let
  inherit (private-settings) domains;
in
{
  vm = {
    id = 2206;
    name = "SRV-MATRIX";

    hardware.cores = 4;
    hardware.memory = 8192;
    hardware.storage = "64G";

    networking.nameservers = [ "192.168.30.13" ];
    networking.openPorts.tcp = [
      443
      8448
    ]
    ++ config.services.matrix-continuwuity.settings.global.port;
  };

  age.secrets.turn = {
    rekeyFile = secrets.gsv-turn;
    owner = config.services.matrix-continuwuity.user;
    inherit (config.services.matrix-continuwuity) group;
  };

  services.matrix-continuwuity = {
    enable = true;
    settings.global = rec {
      allow_announcements_check = false;
      allow_encryption = true;
      allow_registration = false;
      allow_federation = true;
      forbidden_remote_server_names = [ ".*" ]; # livekit requires this
      trusted_servers = lib.mkForce [ ];

      server_name = "matrix.${domains.home}";
      address = [ "0.0.0.0" ];
      port = [ 6167 ];

      turn_uris =
        let
          inherit (outputs.nixosConfigurations.gsv.config.services) coturn;
        in
        [
          "turns:turn.${domains.blog}:${toString coturn.tls-listening-port}"
          "turn:turn.${domains.blog}:${toString coturn.listening-port}"
        ];
      turn_secret_file = config.age.secrets.turn.path;

      new_user_displayname_suffix = "";
      max_request_size = 1000000000; # 1GB

      well_known = {
        client = "https://${server_name}";
        server = "${server_name}:443";
      };
    };
    settings.global.matrix_rtc.foci = [
      {
        type = "livekit";
        livekit_service_url = "https://livekit.${domains.blog}";
      }
    ];
  };

  nas.backup.enable = true;
  rsync."matrix" = {
    tasks = [
      {
        from = "${config.services.matrix-continuwuity.settings.global.database_path}";
        to = "${config.nas.backup.stateLocation}/matrix";
        chown = "${config.services.matrix-continuwuity.user}:${config.services.matrix-continuwuity.group}";
      }
    ];
  };
}
