{ config, lib, ... }:
let
  a = lib.mapAttrs (_: v: v.name) config.hass.entities.area;

  thermometer = id: area: {
    inherit id area;
    sensor = [
      "humidity"
      "temperature"
    ];
    diagnostic = [ "battery" ];
  };

  thermometerPressure =
    id: area:
    (thermometer id area)
    // {
      sensor = [
        "humidity"
        "pressure"
        "temperature"
      ];
    };

  steckdose = id: area: {
    inherit id area;
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
  };

  button = id: area: {
    inherit id area;
    diagnostic = [ "battery" ];
  };
in
{
  hass.persons = {
    Charlotte.phone = "xiaomi_15";
    Marie.phone = "smartiphone";
  };

  hass.devices = {
    media_players = {
      alle = { };
      living_room.area = a.wohnzimmer;
      office.area = a.buro;
      lg_c4.area = a.wohnzimmer;
    };

    vacuums.botty.area = a.wohnzimmer;
    fans.xiaomi_smart_fan.area = a.wohnzimmer;
    images.botty_live_map.area = a.wohnzimmer;
    suns.sun = { };
    weathers.openweathermap = { };

    sensors = {
      rain_rate.area = a.terrasse;
      cumulative_rain_8h.area = a.terrasse;
      cumulative_rain_24h.area = a.terrasse;
      zigbee_min_battery = { };
      botty_current_clean_area.area = a.wohnzimmer;
      botty_aktuelle_reinigungsdauer.area = a.wohnzimmer;
      botty_aktueller_reinigungsbereich.area = a.wohnzimmer;
      botty_restkapazitat_der_hauptburste.area = a.wohnzimmer;
      botty_restkapazitat_der_seitenburste.area = a.wohnzimmer;
      botty_filter_restkapazitat.area = a.wohnzimmer;
      botty_bis_sensorreinigung_verbleibend.area = a.wohnzimmer;
      delayed_thermometer_gewachshaus_temperature.area = a.terrasse;
      tursensor_last_changed.area = a.wohnzimmer;
      openweathermap_gefuhlte_temperatur = { };
      openweathermap_temperatur = { };
      openweathermap_windgeschwindigkeit = { };
      openweathermap_bewolkung = { };
      openweathermap_regenintensitat = { };
      openweathermap_windboengeschwindigkeit = { };
      openweathermap_forecast_daily = { };
      openweathermap_forecast_hourly = { };
      sun_next_dawn = { };
      sun_next_dusk = { };
    };

    input_booleans = {
      settings_garten_anzucht = {
        name = "Garten: Anzucht";
        icon = "mdi:sprout";
        area = a.terrasse;
      };
      settings_garten_bewasserung = {
        name = "Garten: Bewässerung";
        icon = "mdi:water";
        area = a.terrasse;
      };
      settings_garten_heizung = {
        name = "Garten: Heizung";
        icon = "mdi:radiator";
        area = a.terrasse;
      };
      # Latches when the watering window was skipped due to rain; the
      # next non-skipped run notifies on resumption and clears it.
      pumpe_uebersprungen = {
        name = "Pumpe übersprungen (Regen)";
        icon = "mdi:weather-rainy";
        area = a.terrasse;
      };
      turalarm = {
        name = "Türalarm";
        area = a.wohnzimmer;
      };
      turalarm_persistent = {
        name = "Türalarm (dauerhaft)";
        area = a.wohnzimmer;
      };
      botty_wohnzimmer_reinigen = {
        name = "Botty: Wohnzimmer reinigen";
        area = a.wohnzimmer;
      };
      botty_buro_reinigen = {
        name = "Botty: Büro reinigen";
        area = a.wohnzimmer;
      };
      botty_kueche_reinigen = {
        name = "Botty: Küche reinigen";
        area = a.wohnzimmer;
      };
      botty_sofa_reinigen = {
        name = "Botty: Sofa reinigen";
        area = a.wohnzimmer;
      };
    };

    input_numbers = {
      botty_wiederholungen = {
        name = "Botty: Wiederholungen";
        min = 1;
        max = 3;
        step = 1;
        initial = 1;
        area = a.wohnzimmer;
      };
      stunden_sonnenlicht_setzlinge = {
        name = "Sonnenlicht-Stunden (Setzlinge)";
        min = 1;
        max = 24;
        step = 1;
        initial = 14;
        area = a.terrasse;
      };
    };

    zigbee = {
      "Bewegungsmelder" = {
        id = "00:12:4b:00:2a:64:f5:1f";
        area = a.schlafzimmer;
        binary_sensor = [ "motion" ];
        diagnostic = [ "battery" ];
      };

      "Türsensor" = {
        id = "00:12:4b:00:2f:b4:9d:20";
        area = a.flur;
        binary_sensor = [ "opening" ];
        diagnostic = [ "battery" ];
      };

      "Strahler" = {
        id = "00:17:88:01:08:5b:76:98";
        area = a.wohnzimmer;
        light = [ "light" ];
        number = [
          "start_up_color_temperature"
          "start_up_current_level"
        ];
      };

      "Wetterstation" = {
        id = "08:b9:5f:ff:fe:d4:0f:1f";
        area = a.terrasse;
        binary_sensor = [ "moisture" ];
        sensor = [
          "gust_speed"
          "humidity"
          "illuminance"
          "pressure"
          "precipitation"
          "temperature"
          "uv_index"
          "wind_direction"
          "wind_speed"
        ];
        diagnostic = [ "battery" ];
      };

      "Thermometer Badezimmer" = thermometer "00:12:4b:00:2a:5d:46:ac" a.badezimmer;
      "Thermometer Büro" = thermometer "00:12:4b:00:2a:5c:b0:a1" a.buro;
      "Thermometer Filamentbox" = thermometer "00:12:4b:00:2a:5d:1c:3e" a.buro;
      "Thermometer Schlafzimmer" = thermometer "00:12:4b:00:2a:5c:b4:14" a.schlafzimmer;
      "Thermometer Serverschrank" = thermometer "00:12:4b:00:2a:5d:0e:3e" a.buro;
      "Thermometer Wohnzimmer" = thermometer "00:12:4b:00:2a:5d:23:0b" a.wohnzimmer;

      "Thermometer Gewächshaus" = thermometerPressure "00:15:8d:00:09:45:19:da" a.terrasse;
      "Thermometer Nordseite" = thermometerPressure "00:15:8d:00:09:45:18:3a" a.terrasse;

      "Steckdose Serverschrank" = steckdose "a4:c1:38:a7:09:97:ff:85" a.buro;
      "Steckdose Gewächshaus Heizung" = steckdose "a4:c1:38:e4:68:4c:2e:f8" a.terrasse;
      "Steckdose Wasserpumpe" = steckdose "a4:c1:38:7a:85:ae:fb:a3" a.terrasse;
      "Steckdose Pflanzenlicht" = steckdose "a4:c1:38:5a:fc:f5:62:61" a.wohnzimmer;

      "Button Sofa" = button "f0:44:d3:ff:fe:f9:8a:60" a.wohnzimmer;
      "Button Gewächshaus" = button "f0:44:d3:ff:fe:f9:86:c4" a.terrasse;
      "Button Büro" = button "f0:44:d3:ff:fe:f6:9e:0c" a.buro;
    };
  };
}
