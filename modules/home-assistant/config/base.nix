{ pkgs, ... }:
{
  services.home-assistant = {
    extraPackages =
      python3Packages:
      let
        p = pkgs.ours.home-assistant.custom-components.mkVacuumParsers python3Packages;
      in
      with python3Packages;
      [
        ical
        python-miio
        joserfc
        vacuum-map-parser-base
        vacuum-map-parser-roborock
        pkgs.ours.hass-grocery-categorize
        p.vacuum-map-parser-dreame
        p.vacuum-map-parser-ijai
        p.vacuum-map-parser-roidmi
        p.vacuum-map-parser-viomi
        p.vacuum-map-parser-xiaomi
      ];

    extraComponents = [
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
        ip_ban_enabled = true;
        trusted_proxies = [
          "192.168.24.3"
          "192.168.24.2"
        ];
        login_attempts_threshold = 5;
      };
    };
  };
}
