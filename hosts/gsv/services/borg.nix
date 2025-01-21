{ config, private-settings, ... }:
{
  sops.secrets.borg = { };
  services.borgbackup.jobs.remoteBackup = {
    paths = [
      "/var/vmail"
      "/var/lib/radicale"
    ];
    exclude = [
      "'**/node_modules'"
      "'**/.venv'"
      "'**/.cache'"
    ];
    doInit = false;
    repo = "${private-settings.domains.cloudsync}:gsv";
    encryption = {
      mode = "repokey";
      passCommand = "cat ${config.sops.secrets.borg.path}";
    };
    environment = {
      BORG_RSH = "ssh -p 23 -i /etc/ssh/ssh_host_ed25519_key";
    };
    compression = "auto,lzma";
    startAt = "02:15";
  };
}
