{
  config,
  pkgs,
  private-settings,
  secrets,
  ...
}:
{
  vm = {
    id = 2224;
    name = "SRV-TREK";

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "32G";
  };

  services.trek = {
    enable = true;
    package = pkgs.ours.trek;

    address = "0.0.0.0";
    openFirewall = true;

    appUrl = "https://trek.${private-settings.domains.home}";
    proxy.trustedHops = 1;

    settings.defaultLanguage = "de";
    settings.allowInternalNetwork = true;

    secretsFile = config.age.secrets.trek-env.path;
  };
  age.secrets.trek-env.rekeyFile = secrets.trek-env;

  nas.backup.enable = true;
  rsync."trek" = {
    tasks = [
      {
        from = "/var/lib/trek";
        to = "${config.nas.backup.stateLocation}/trek";
        extraFlags = "--exclude=app/";
        chown = null;
      }
    ];
  };
}
