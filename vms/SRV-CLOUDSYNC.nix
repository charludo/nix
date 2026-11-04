{
  config,
  options,
  secrets,
  ...
}:
{
  vm = {
    id = 3012;
    name = "SRV-CLOUDSYNC";
    unsupervisedUpdates = true;

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "16G";
  };

  nas.enable = true;
  nas.backup.enable = true;

  borg.cloudsync = {
    paths = [
      "${config.nas.location}/CloudSync"
      "${config.nas.location}/Musik"
      "${config.nas.location}/Paperless"
      "${config.nas.backup.stateLocation}"
    ];
    exclude = (options.borg.type.nestedTypes.elemType.getSubOptions [ ]).exclude.default ++ [
      "${config.nas.backup.stateLocation}/immich/upload" # transit dir, vanishing files cause backup error
    ];
    startAt = "03:15";
    secrets.password = secrets.borg-password-cloudsync;
    secrets.sshKey = secrets.borg-ssh;
  };
}
