{
  config,
  private-settings,
  secrets,
  ...
}:
{
  vm = {
    id = 2208;
    name = "SRV-KAVITA";

    hardware.cores = 4;
    hardware.memory = 8192;
    hardware.storage = "16G";

    networking.nameservers = private-settings.upstreamDNS.ips;
    networking.openPorts.tcp = [ config.services.kavita.settings.Port ];
  };

  age.secrets.kavita-token.rekeyFile = secrets.kavita-token;

  services.kavita = {
    enable = true;
    tokenKeyFile = config.age.secrets.kavita-token.path;
    settings.IpAddresses = "0.0.0.0";
  };

  nas.enable = true;
  nas.extraUsers = [ config.services.kavita.user ];

  nas.backup.enable = true;
  rsync."kavita" = {
    tasks = [
      {
        from = "${config.services.kavita.dataDir}";
        to = "${config.nas.backup.stateLocation}/kavita";
        chown = "${config.services.kavita.user}:*";
      }
    ];
  };
}
