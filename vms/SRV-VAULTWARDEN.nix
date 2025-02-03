{
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
    backupDir = "${config.nas.backup.location}/vaultwarden";
    config = {
      DOMAIN = "https://passwords.${domains.home}";
      SIGNUPS_ALLOWED = false;
      ROCKET_ADDRESS = "0.0.0.0";
      ROCKET_PORT = 8222;
    };
    # include environmentFile to enable admin backend
    # environmentFile = config.age.secrets.vaultwarden.path;
  };

  nas.enable = true;
  nas.backup.enable = true;
  nas.extraUsers = [ "vaultwarden" ];

  environment.systemPackages =
    let
      vaultwarden-init = pkgs.writeShellApplication {
        name = "vaultwarden-init";
        runtimeInputs = [ pkgs.rsync ];
        text = ''
          ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.vaultwarden.backupDir}/ /var/lib/vaultwarden
        '';
      };
    in
    [
      vaultwarden-init
      pkgs.rsync
    ];

  system.stateVersion = "24.11";
}
