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
    ./devices
    ./intents
    ./scripts

    ./areas.nix
    ./assets.nix
    ./buttons.nix
    ./lgtv.nix
    ./misc.nix
    ./music-assistant.nix
    ./oidc.nix
    ./shopping.nix
    ./sonos.nix
    ./timers.nix
    ./voice.nix
    ./weather.nix
    ./xiaomi.nix
  ];

  services.home-assistant = {
    enable = true;
    openFirewall = true;
    lovelaceConfigWritable = false;

    extraPackages =
      python3Packages:
      let
        p = pkgs.ours.home-assistant.custom-components.mkVacuumParsers python3Packages;
      in
      with python3Packages;
      [
        psycopg2

        ical
        python-miio
        joserfc
        vacuum-map-parser-base
        vacuum-map-parser-roborock
        pkgs.ours.home-assistant.grocery-categorize-cli
        p.vacuum-map-parser-dreame
        p.vacuum-map-parser-ijai
        p.vacuum-map-parser-roidmi
        p.vacuum-map-parser-viomi
        p.vacuum-map-parser-xiaomi
      ];

    extraComponents = [
      "default_config"
      "mobile_app"
      "isal"

      "sun"
      "history"
      "statistics"

      "google_translate"
      "met"
      "webostv"
    ];

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

      http = {
        use_x_forwarded_for = true;
        ip_ban_enabled = false;
        trusted_proxies = [
          "192.168.24.3"
          "192.168.24.2"
        ];
      };

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

  hass.reconciler = {
    enable = true;
    tokenPath = config.age.secrets.hass-reconciler-token.path;
  };
  hass.bambu.enable = true;
  hass.massSlotLists = {
    enable = true;
    massTokenPath = config.age.secrets.mass-token.path;
    hassTokenPath = config.age.secrets.hass-mass-token.path;
  };
  hass.closestIntent.enable = true;
  hass.openweathermap.enable = true;
}
