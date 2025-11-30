{ config, ... }:
{
  vm = {
    id = 2216;
    name = "SRV-PINCHFLAT";

    hardware.cores = 2;
    hardware.memory = 8192;
    hardware.storage = "16G";

    certsFor = [
      {
        name = "pinchflat";
        port = config.services.pinchflat.port;
        defaultProxySettings = false;
      }
    ];
  };

  services.pinchflat = {
    enable = true;
    selfhosted = true;
    mediaDir = config.nas.location;
  };

  systemd.services.pinchflat = {
    after = [ "media-NAS.mount" ];
    partOf = [ "media-NAS.mount" ];
  };

  nas.enable = true;
  nas.extraUsers = [ config.services.pinchflat.user ];

  nas.backup.enable = true;
  rsync."pinchflat" = {
    tasks = [
      {
        from = "/var/lib/pinchflat";
        to = "${config.nas.backup.stateLocation}/pinchflat";
        chown = "pinchflat:pinchflat";
      }
    ];
  };
}
