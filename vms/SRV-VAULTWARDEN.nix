{
  config,
  private-settings,
  secrets,
  ...
}:
let
  inherit (private-settings) domains;
in
{
  vm = {
    id = 2210;
    name = "SRV-VAULTWARDEN";

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "16G";

    networking.openPorts.tcp = [ config.services.vaultwarden.config.ROCKET_PORT ];
  };

  age.secrets.vaultwarden.rekeyFile = secrets.vaultwarden-admin-token;

  services.vaultwarden = {
    enable = true;
    config = {
      DOMAIN = "https://passwords.${domains.home}";
      SIGNUPS_ALLOWED = false;
      ROCKET_ADDRESS = "0.0.0.0";
      ROCKET_PORT = 8222;
    };
    # include environmentFile to enable admin backend
    # environmentFile = config.age.secrets.vaultwarden.path;
  };

  nas.backup.enable = true;
  rsync."vaultwarden" = {
    tasks = [
      {
        from = "/var/lib/vaultwarden";
        to = "${config.nas.backup.stateLocation}/vaultwarden";
        chown = "${config.users.users.vaultwarden.name}:${config.users.groups.vaultwarden.name}";
      }
    ];
  };

  # vaultwarden was named bitwarden_rs in prior versions and had a different data dir
  system.stateVersion = "24.11";
}
