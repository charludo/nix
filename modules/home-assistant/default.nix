{
  config,
  secrets,
  ...
}:
{
  imports = [
    ./automations.nix
    ./devices.nix
    ./integrations
    ./scripts.nix
    ./timers.nix
  ];

  services.home-assistant = {
    enable = true;
    openFirewall = true;
    lovelaceConfigWritable = false;

    extraPackages = python3Packages: [ python3Packages.psycopg2 ];

    extraComponents = [
      "default_config"
      "mobile_app"
      "isal"

      "sun"
      "history"
      "statistics"
    ];

    config = {
      recorder.db_url = "postgresql://@/hass";
      logger.default = "warn";
      mobile_app = { };
      history = { };
      sun = { };
    };
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "hass" ];
    ensureUsers = [
      {
        name = "hass";
        ensureDBOwnership = true;
      }
    ];
  };

  age.secrets.hass-secrets = {
    rekeyFile = secrets.hass-secrets;
    path = "${config.services.home-assistant.configDir}/secrets.yaml";
    owner = "hass";
    group = "hass";
  };

  age.secrets.hass-reconciler-token = {
    rekeyFile = secrets.hass-reconciler-token;
    owner = "hass";
    group = "hass";
  };

  hass.zha.reconciler.enable = true;
}
