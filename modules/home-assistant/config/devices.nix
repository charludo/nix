let
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

    vacuums.botty.area = "Wohnzimmer";
    fans.xiaomi_smart_fan.area = "Wohnzimmer";
    images.botty_live_map.area = "Wohnzimmer";
    suns.sun = { };
    weathers.openweathermap = { };

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
        area = "Schlafzimmer";
        binary_sensor = [ "motion" ];
        diagnostic = [ "battery" ];
      };

      "Türsensor" = {
        id = "00:12:4b:00:2a:64:f5:20";
        area = "Wohnzimmer";
        binary_sensor = [ "opening" ];
        diagnostic = [ "battery" ];
      };

      "Strahler" = {
        id = "00:17:88:01:08:5b:76:98";
        area = "Wohnzimmer";
        light = [ "light" ];
        number = [
          "start_up_color_temperature"
          "start_up_current_level"
        ];
      };

      "Wetterstation" = {
        id = "08:b9:5f:ff:fe:d4:0f:1f";
        area = "Terrasse";
        binary_sensor = [ "moisture" ];
        sensor = [
          "humidity"
          "illuminance"
          "pressure"
          "precipitation"
          "temperature"
          "uv_index"
          "wind_direction"
          "wind_gust_speed"
          "wind_speed"
        ];
        diagnostic = [ "battery" ];
      };

      "Thermometer Badezimmer" = thermometer "00:12:4b:00:2a:5d:46:ac" "Badezimmer";
      "Thermometer Büro" = thermometer "00:12:4b:00:2a:5c:b0:a1" "Büro";
      "Thermometer Filamentbox" = thermometer "00:12:4b:00:2a:5d:1c:3e" "Büro";
      "Thermometer Schlafzimmer" = thermometer "00:12:4b:00:2a:5c:b4:14" "Schlafzimmer";
      "Thermometer Serverschrank" = thermometer "00:12:4b:00:2a:5d:0e:3e" "Büro";
      "Thermometer Wohnzimmer" = thermometer "00:12:4b:00:2a:5d:23:0b" "Wohnzimmer";

      "Thermometer Gewächshaus" = thermometerPressure "00:15:8d:00:09:45:19:da" "Terrasse";
      "Thermometer Nordseite" = thermometerPressure "00:15:8d:00:09:45:18:3a" "Terrasse";

      "Steckdose Serverschrank" = steckdose "a4:c1:38:5a:fc:f5:62:61" "Büro";
      "Steckdose Gewächshaus Heizung" = steckdose "a4:c1:38:e4:68:4c:2e:f8" "Terrasse";
      "Steckdose Wasserpumpe" = steckdose "a4:c1:38:7a:85:ae:fb:a3" "Terrasse";
      "Steckdose Pflanzenlicht" = steckdose "a4:c1:38:e4:68:4c:2e:01" "Terrasse";

      "Button Sofa" = button "f0:44:d3:ff:fe:f9:8a:60" "Wohnzimmer";
      "Button Gewächshaus" = button "f0:44:d3:ff:fe:f9:86:c4" "Terrasse";
      "Button Büro" = button "f0:44:d3:ff:fe:f6:9e:0c" "Büro";
    };
  };
}
