{ config, private-settings, secrets, ... }:
{
  imports = [ ./_common.nix ];

  vm = {
    id = 3012;
    name = "SRV-CLOUDSYNC";

    hardware.cores = 2;
    hardware.memory = 2048;
    hardware.storage = "12G";

    networking.nameservers = [ ];
  };

  enableNas = true;

  sops.secrets.borg = { sopsFile = secrets.cloudsync; };
  services.borgbackup.jobs.remoteBackup = {
    paths = [ "/media/NAS/CloudSync" ];
    exclude = [ "'**/node_modules'" "'**/.venv'" "'**/.cache'" ];
    doInit = false;
    repo = "${private-settings.domains.cloudsync}:pakiplace";
    encryption = {
      mode = "repokey";
      passCommand = "cat ${config.sops.secrets.borg.path}";
    };
    environment = { BORG_RSH = "ssh -p 23 -i /etc/ssh/ssh_host_ed25519_key"; };
    compression = "auto,lzma";
    startAt = "03:15";
  };

  system.stateVersion = "23.11";
}
