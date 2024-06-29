{ config, pkgs, inputs, ... }:
{
  imports = [ ./_common.nix ];

  vm = {
    id = 3012;
    name = "SRV-CLOUDSYNC";

    hardware.cores = 2;
    hardware.memory = 2048;
    hardware.storage = "12G";

    networking.address = "192.168.30.31";
    networking.gateway = "192.168.30.1";
    networking.prefixLength = 24;
    networking.nameservers = [ ];
  };

  enableNas = true;

  sops.secrets.borg = { sopsFile = ./secrets/cloudsync-secrets.sops.yaml; };
  services.borgbackup.jobs.remoteBackup = {
    paths = [ "/media/NAS/CloudSync" ];
    exclude = [ "'**/node_modules'" "'**/.venv'" "'**/.cache'" ];
    doInit = false;
    repo = "${inputs.private-settings.domains.cloudsync}:pakiplace";
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
