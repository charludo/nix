{ config, pkgs, private-settings, secrets, ... }:
let
  inherit (private-settings) domains;
in
{
  imports = [ ./_common.nix ];

  vm = {
    id = 2210;
    name = "SRV-VAULTWARDEN";

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "16G";

    networking.openPorts.tcp = [ config.services.vaultwarden.config.ROCKET_PORT ];
  };

  sops.secrets.vaultwarden = { sopsFile = secrets.vaultwarden; };
  services.vaultwarden = {
    enable = true;
    backupDir = "/media/Backup/vaultwarden";
    config = {
      DOMAIN = "https://passwords.${domains.home}";
      SIGNUPS_ALLOWED = false;
      ROCKET_ADDRESS = "0.0.0.0";
      ROCKET_PORT = 8222;
    };
    # environmentFile = config.sops.secrets.vaultwarden.path;
  };

  enableNas = true;
  enableNasBackup = true;
  users.users.vaultwarden.extraGroups = [ "nas" ];

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
    [ vaultwarden-init pkgs.rsync ];

  system.stateVersion = "24.11";
}
