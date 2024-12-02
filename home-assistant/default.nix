{
  config,
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
    ./database.nix
    ./lgtv.nix
    ./misc.nix
    ./music-assistant.nix
    ./news.nix
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
      python3Packages: with python3Packages; [
        ical
      ];

    extraComponents = [
      "default_config"
      "mobile_app"
      "isal"

      "history"

      "google_translate"
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

      logger.default = "warn";
      mobile_app = { };
      history = { };
    };
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
}
