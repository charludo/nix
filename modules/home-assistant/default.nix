{
  config,
  pkgs,
  secrets,
  ...
}:
{
  imports = [
    ./automations
    ./dashboards
    ./devices.nix
    ./integrations
    ./intents
    ./scripts
  ];
  options = { };

  config = {
    services.home-assistant = {
      enable = true;
      openFirewall = true;

      extraPackages =
        python3Packages:
        with python3Packages;
        let
          p = pkgs.ours.home-assistant.custom-components.mkVacuumParsers python3Packages;
        in
        [
          psycopg2

          python-miio
          joserfc
          vacuum-map-parser-base
          vacuum-map-parser-roborock
          p.vacuum-map-parser-dreame
          p.vacuum-map-parser-ijai
          p.vacuum-map-parser-roidmi
          p.vacuum-map-parser-viomi
          p.vacuum-map-parser-xiaomi
        ];
      config.recorder.db_url = "postgresql://@/hass";

      extraComponents = [
        "default_config"
        "mobile_app"
        "google_translate"
        "met"
        "isal"

        "sun"
        "history"
        "statistics"
        "webostv"
      ];

      lovelaceConfigWritable = false;
      config = {
        homeassistant = {
          name = "Home";
          unit_system = "metric";
          currency = "EUR";
          country = "DE";
          language = "de";
          time_zone = "Europe/Berlin";
          latitude = "!secret latitude";
          longitude = "!secret longitude";
        };

        logger.default = "warn";
        mobile_app = { };

        history = { };
        sun = { };

        http = {
          use_x_forwarded_for = true;
          ip_ban_enabled = true;
          trusted_proxies = [
            "192.168.24.3"
            "192.168.24.2"
          ];
          login_attempts_threshold = 5;
        };
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
  };
}
