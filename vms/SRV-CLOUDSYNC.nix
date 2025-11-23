{
  config,
  private-settings,
  secrets,
  ...
}:
{
  vm = {
    id = 3012;
    name = "SRV-CLOUDSYNC";

    hardware.cores = 2;
    hardware.memory = 2048;
    hardware.storage = "12G";
  };

  nas.enable = true;
  nas.backup.enable = true;

  age.secrets.borg.rekeyFile = secrets.cloudsync-borg;

  services.borgbackup.jobs.remoteBackup = {
    paths = [
      "${config.nas.location}/CloudSync"
      "${config.nas.location}/Musik"
      "${config.nas.location}/Paperless"
      "${config.nas.backup.stateLocation}"
    ];
    exclude = [
      "'**/node_modules'"
      "'**/.venv'"
      "'**/.cache'"
    ];
    doInit = false;
    repo = "${private-settings.domains.cloudsync}:pakiplace";
    encryption = {
      mode = "repokey";
      passCommand = "cat ${config.age.secrets.borg.path}";
    };
    environment = {
      BORG_RSH = "ssh -p 23 -i /etc/ssh/ssh_host_ed25519_key";
    };
    compression = "auto,lzma";
    startAt = "03:15";
  };

  system.stateVersion = "23.11";
}
