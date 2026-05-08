{ config, ... }:
let
  e = config.hass.entities;
in
{
  imports = [ ../modules/home-assistant ];

  vm = {
    id = 2403;
    name = "SRV-HOMEASSISTANT";

    hardware.cores = 4;
    hardware.memory = 16384;
    hardware.storage = "8G";

    networking.openPorts.tcp = [
      8123
      8927
      8095
      1400
    ];
    networking.openPorts.udp = [
      8123
      8927
      8095
      1400
    ];
  };

  # nas.backup.enable = true;
  #
  # services.postgresqlBackup = {
  #   enable = true;
  #   databases = [ "hass" ];
  #   compression = "zstd";
  # };
  #
  # rsync."srv-homeassistant" = {
  #   tasks = [
  #     {
  #       from = config.services.home-assistant.configDir;
  #       to = "${config.nas.backup.stateLocation}/hass";
  #       chown = "hass:hass";
  #       extraFlags = "--exclude=secrets.yaml";
  #     }
  #     {
  #       from = "/var/lib/music-assistant";
  #       to = "${config.nas.backup.stateLocation}/music-assistant";
  #     }
  #     {
  #       from = config.services.postgresqlBackup.location;
  #       to = "${config.nas.backup.stateLocation}/postgresql";
  #     }
  #   ];
  # };

  services.music-assistant = {
    enable = true;
    openFirewall = true;
    providers = [
      "jellyfin"
      "audiobookshelf"

      "sonos"
      "hass_players"
      "universal_group"

      "chromecast"
      "sendspin"
      "dlna"
    ];
  };

  hass.areas = {
    "Terrasse" = {
      order = 1;
      icon = "mdi:sprout";
      temperatureEntity = e.sensor.thermometer_terrasse.temperature;
      humidityEntity = e.sensor.thermometer_terrasse.humidity;
    };
    "Wohnzimmer" = {
      order = 2;
      icon = "mdi:sofa";
      temperatureEntity = e.sensor.thermometer_wohnzimmer.temperature;
      humidityEntity = e.sensor.thermometer_wohnzimmer.humidity;
    };
    "Büro" = {
      order = 3;
      icon = "mdi:desktop-classic";
      temperatureEntity = e.sensor.thermometer_buro.temperature;
      humidityEntity = e.sensor.thermometer_buro.humidity;
    };
    "Schlafzimmer" = {
      order = 4;
      icon = "mdi:bed-king";
      temperatureEntity = e.sensor.thermometer_schlafzimmer.temperature;
      humidityEntity = e.sensor.thermometer_schlafzimmer.humidity;
    };
    "Badezimmer" = {
      order = 5;
      icon = "mdi:shower";
      temperatureEntity = e.sensor.thermometer_badezimmer.temperature;
      humidityEntity = e.sensor.thermometer_badezimmer.humidity;
    };
    "Flur" = {
      order = 6;
      icon = "mdi:door";
    };
  };

  hass.botty.zones = {
    # Each slug must match input_boolean.botty_<slug>_reinigen.
    # Coords are vacuum-map-space rectangles. Re-harvest from the
    # interactive `vacuum_clean_zone` mode if the map ever rebuilds.
    sofa = {
      x1 = 23500;
      y1 = 25150;
      x2 = 26300;
      y2 = 29250;
    };
    kueche = {
      x1 = 19510;
      y1 = 25150;
      x2 = 23500;
      y2 = 27700;
    };
    wohnzimmer = {
      x1 = 19510;
      y1 = 25150;
      x2 = 26300;
      y2 = 31250;
    };
    buro = {
      x1 = 20250;
      y1 = 31300;
      x2 = 26250;
      y2 = 35100;
    };
  };

  hass.devices = {
    mobile_apps = {
      "Phone Charlotte" = { };
      "Phone Marie" = { };
    };

    media_players = {
      alle = { };
      living_room.area = "Wohnzimmer";
      office.area = "Büro";
      lg_c4.area = "Wohnzimmer";
    };

    vacuums = {
      botty.area = "Wohnzimmer";
    };

    fans = {
      xiaomi_smart_fan.area = "Wohnzimmer";
    };

    images = {
      botty_live_map.area = "Wohnzimmer";
    };

    suns = {
      sun = { };
    };

    weathers = {
      openweathermap = { };
    };

    sensors = {
      cumulative_rain_8h.area = "Terrasse";
      cumulative_rain_24h.area = "Terrasse";
      botty_current_clean_area.area = "Wohnzimmer";
      botty_aktuelle_reinigungsdauer.area = "Wohnzimmer";
      botty_aktueller_reinigungsbereich.area = "Wohnzimmer";
      botty_restkapazitat_der_hauptburste.area = "Wohnzimmer";
      botty_restkapazitat_der_seitenburste.area = "Wohnzimmer";
      botty_filter_restkapazitat.area = "Wohnzimmer";
      botty_bis_sensorreinigung_verbleibend.area = "Wohnzimmer";
      delayed_thermometer_gewachshaus_temperature.area = "Terrasse";
      tursensor_last_changed.area = "Wohnzimmer";
      openweathermap_gefuhlte_temperatur = { };
      openweathermap_temperatur = { };
      openweathermap_windgeschwindigkeit = { };
      openweathermap_bewolkung = { };
      openweathermap_regenintensitat = { };
      openweathermap_windboengeschwindigkeit = { };
      openweathermap_forecast_daily = { };
      openweathermap_forecast_hourly = { };
      weather_wind_gust.area = "Terrasse";
      sun_next_dawn = { };
      sun_next_dusk = { };
    };

    input_booleans = {
      settings_garten_anzucht = {
        name = "Garten: Anzucht";
        icon = "mdi:sprout";
        area = "Terrasse";
      };
      settings_garten_bewasserung = {
        name = "Garten: Bewässerung";
        icon = "mdi:water";
        area = "Terrasse";
      };
      settings_garten_heizung = {
        name = "Garten: Heizung";
        icon = "mdi:radiator";
        area = "Terrasse";
      };
      turalarm = {
        name = "Türalarm";
        area = "Wohnzimmer";
      };
      turalarm_persistent = {
        name = "Türalarm (dauerhaft)";
        area = "Wohnzimmer";
      };
      botty_wohnzimmer_reinigen = {
        name = "Botty: Wohnzimmer reinigen";
        area = "Wohnzimmer";
      };
      botty_buro_reinigen = {
        name = "Botty: Büro reinigen";
        area = "Wohnzimmer";
      };
      botty_kueche_reinigen = {
        name = "Botty: Küche reinigen";
        area = "Wohnzimmer";
      };
      botty_sofa_reinigen = {
        name = "Botty: Sofa reinigen";
        area = "Wohnzimmer";
      };
    };

    input_numbers = {
      botty_wiederholungen = {
        name = "Botty: Wiederholungen";
        min = 1;
        max = 3;
        step = 1;
        initial = 1;
        area = "Wohnzimmer";
      };
      stunden_sonnenlicht_setzlinge = {
        name = "Sonnenlicht-Stunden (Setzlinge)";
        min = 1;
        max = 24;
        step = 1;
        initial = 14;
        area = "Terrasse";
      };
    };

    zigbee = {
      "Bewegungsmelder" = {
        id = "00:12:4b:00:2a:64:f5:1f";
        binary_sensor = [ "motion" ];
        diagnostic = [ "battery" ];
        area = "Schlafzimmer";
      };

      "Steckdose Serverschrank" = {
        id = "a4:c1:38:a7:09:97:ff:85";
        sensor = [
          "current"
          "power"
          "summation_delivered"
          "voltage"
        ];
        switch = [
          "child_lock"
          "switch"
        ];
        select = [
          "backlight_mode"
          "power_on_state"
        ];
        area = "Büro";
      };

      "Steckdose Gewächshaus Heizung" = {
        id = "a4:c1:38:e4:68:4c:2e:f8";
        sensor = [
          "current"
          "power"
          "summation_delivered"
          "voltage"
        ];
        switch = [
          "child_lock"
          "switch"
        ];
        select = [
          "backlight_mode"
          "power_on_state"
        ];
        area = "Terrasse";
      };

      "Steckdose Wasserpumpe" = {
        id = "a4:c1:38:7a:85:ae:fb:a3";
        sensor = [
          "current"
          "power"
          "summation_delivered"
          "voltage"
        ];
        switch = [
          "child_lock"
          "switch"
        ];
        select = [
          "backlight_mode"
          "power_on_state"
        ];
        area = "Terrasse";
      };

      "Thermometer Badezimmer" = {
        id = "00:12:4b:00:2a:5d:46:ac";
        sensor = [
          "humidity"
          "temperature"
        ];
        diagnostic = [ "battery" ];
        area = "Badezimmer";
      };

      "Thermometer Büro" = {
        id = "00:12:4b:00:2a:5c:b0:a1";
        sensor = [
          "humidity"
          "temperature"
        ];
        diagnostic = [ "battery" ];
        area = "Büro";
      };

      "Thermometer Filamentbox" = {
        id = "00:12:4b:00:2a:5d:1c:3e";
        sensor = [
          "humidity"
          "temperature"
        ];
        diagnostic = [ "battery" ];
        area = "Büro";
      };

      "Thermometer Schlafzimmer" = {
        id = "00:12:4b:00:2a:5c:b4:14";
        sensor = [
          "humidity"
          "temperature"
        ];
        diagnostic = [ "battery" ];
        area = "Schlafzimmer";
      };

      "Thermometer Serverschrank" = {
        id = "00:12:4b:00:2a:5d:0e:3e";
        sensor = [
          "humidity"
          "temperature"
        ];
        diagnostic = [ "battery" ];
        area = "Büro";
      };

      "Thermometer Wohnzimmer" = {
        id = "00:12:4b:00:2a:5d:23:0b";
        sensor = [
          "humidity"
          "temperature"
        ];
        diagnostic = [ "battery" ];
        area = "Wohnzimmer";
      };

      "Thermometer Gewächshaus" = {
        id = "00:15:8d:00:09:45:19:da";
        sensor = [
          "humidity"
          "pressure"
          "temperature"
        ];
        diagnostic = [ "battery" ];
        area = "Terrasse";
      };

      "Thermometer Terrasse" = {
        id = "00:15:8d:00:09:45:18:3a";
        sensor = [
          "humidity"
          "pressure"
          "temperature"
        ];
        diagnostic = [ "battery" ];
        area = "Terrasse";
      };

      "Türsensor" = {
        id = "00:12:4b:00:2a:64:f5:20";
        binary_sensor = [ "opening" ];
        diagnostic = [ "battery" ];
        area = "Wohnzimmer";
      };

      "Steckdose Pflanzenlicht" = {
        id = "a4:c1:38:e4:68:4c:2e:01";
        sensor = [
          "current"
          "power"
          "summation_delivered"
          "voltage"
        ];
        switch = [
          "child_lock"
          "switch"
        ];
        select = [
          "backlight_mode"
          "power_on_state"
        ];
        area = "Terrasse";
      };

      "Strahler" = {
        id = "00:17:88:01:08:5b:76:98";
        light = [ "light" ];
        number = [
          "start_up_color_temperature"
          "start_up_current_level"
        ];
        area = "Wohnzimmer";
      };
    };
  };

  hass.shopping = {
    todo_entity = "todo.shopping_list";
    supermarkets = {
      REWE = {
        color = "var(--red)";
        icon = "mdi:cart";
        categories = [
          "Obst"
          "Gemüse"
          "Backwaren"
          "Aufstrich"
          "Coffee&Tea"
          "Salz&Gewürze"
          "Backzutaten"
          "Delikatessen"
          "Aufschnitt"
          "Nudeln&Reis"
          "Tomatensoße"
          "Konserven"
          "Asia"
          "Soßen"
          "Essig&Öl"
          "Fleisch"
          "Alkohol"
          "Eier"
          "Fisch"
          "Veganes"
          "Milchprodukte"
          "FrischeNudeln"
          "Schreibwaren"
          "Softdrinks"
          "Reinigungsmittel&Müll"
          "Zahnputz"
          "Kosmetik"
          "Seife&Shampoo"
          "Mexiko"
          "Süßwaren"
          "Snacks"
          "Tiefgefrorenes"
          "Sonstiges"
        ];
      };

      Edeka = {
        color = "var(--yellow)";
        icon = "mdi:cart";
        categories = [
          "Gemüse"
          "Obst"
          "Veganes"
          "FrischeNudeln"
          "Eier"
          "Kosmetik"
          "Zahnputz"
          "Seife&Shampoo"
          "Reinigungsmittel&Müll"
          "Essig&Öl"
          "Konserven"
          "Soßen"
          "Aufstrich"
          "Backwaren"
          "Coffee&Tea"
          "Delikatessen"
          "Fisch"
          "Asia"
          "Backzutaten"
          "Nudeln&Reis"
          "Tomatensoße"
          "Aufschnitt"
          "Milchprodukte"
          "Fleisch"
          "Salz&Gewürze"
          "Alkohol"
          "Softdrinks"
          "Süßwaren"
          "Snacks"
          "Mexiko"
          "Schreibwaren"
          "Tiefgefrorenes"
          "Sonstiges"
        ];
      };

      Baumarkt = {
        color = "var(--green)";
        icon = "mdi:excavator";
        categories = [
          "Gartencenter&Baumarkt"
          "Sonstiges"
        ];
      };

      Asiamarkt = {
        color = "var(--blue)";
        icon = "mdi:rice";
        categories = [
          "Asia"
          "Mexiko"
        ];
      };

      Apotheke = {
        color = "var(--white)";
        icon = "mdi:pill-multiple";
        categories = [
          "Apotheke"
        ];
      };
    };
  };
}
