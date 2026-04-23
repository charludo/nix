{
  config,
  private-settings,
  secrets,
  ...
}:
{
  vm = {
    id = 2005;
    name = "SRV-POCKETID";

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "8G";

    networking.openPorts.tcp = [ 1411 ];
  };

  age.secrets.pocketid-encryption-key.rekeyFile = secrets.pocketid-encryption-key;

  services.pocket-id = {
    enable = true;
    credentials = {
      ENCRYPTION_KEY = config.age.secrets.pocketid-encryption-key.path;
    };
    settings = {
      APP_URL = "https://sso.${private-settings.domains.home}";
      TRUST_PROXY = true;
      TRUSTED_PLATFORM = "CF-Connecting-IP";

      UI_CONFIG_DISABLED = true;
      APP_NAME = "Pocket ID";
      SESSION_DURATION = "10800"; # one week
      HOME_PAGE_URL = "settings/apps";
      ALLOW_USER_SIGNUPS = "withToken";
      SIGNUP_DEFAULT_USER_GROUP_IDS = "af6fa27e-153f-44b2-a7d6-847a60855b2c";
      ACCENT_COLOR = "default";
    };
  };

  nas.backup.enable = true;
  rsync."pocket-id" = {
    tasks = [
      {
        from = config.services.pocket-id.dataDir;
        to = "${config.nas.backup.stateLocation}/pocket-id";
        chown = "${config.services.pocket-id.user}:${config.services.pocket-id.group}";
      }
    ];
  };
}
