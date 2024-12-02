{
  services.home-assistant.config = {
    input_boolean = {
      settings_garten_anzucht = {
        name = "Garten: Anzucht";
        icon = "mdi:sprout";
      };
      settings_garten_bewasserung = {
        name = "Garten: Bewässerung";
        icon = "mdi:water";
      };
      settings_garten_heizung = {
        name = "Garten: Heizung";
        icon = "mdi:radiator";
      };

      turalarm = {
        name = "Türalarm";
      };
      turalarm_persistent = {
        name = "Türalarm (dauerhaft)";
      };
      botty_wohnzimmer_reinigen = {
        name = "Botty: Wohnzimmer reinigen";
      };
      botty_buro_reinigen = {
        name = "Botty: Büro reinigen";
      };
      botty_kueche_reinigen = {
        name = "Botty: Küche reinigen";
      };
      botty_sofa_reinigen = {
        name = "Botty: Sofa reinigen";
      };
    };

    input_number = {
      botty_wiederholungen = {
        name = "Botty: Wiederholungen";
        min = 1;
        max = 3;
        step = 1;
        initial = 1;
      };
      stunden_sonnenlicht_setzlinge = {
        name = "Sonnenlicht-Stunden (Setzlinge)";
        min = 1;
        max = 24;
        step = 1;
        initial = 14;
      };
    };

    sensor = [
      {
        platform = "statistics";
        name = "Cumulative Rain 24h";
        entity_id = "sensor.openweathermap_regenintensitat";
        state_characteristic = "sum";
        max_age.hours = 24;
      }
      {
        platform = "statistics";
        name = "Cumulative Rain 8h";
        entity_id = "sensor.openweathermap_regenintensitat";
        state_characteristic = "sum";
        max_age.hours = 8;
      }
    ];

    template = [
      {
        sensor = [
          {
            name = "Delayed Thermometer Gewächshaus Temperature";
            state = "{{ states('sensor.thermometer_gewachshaus_temperature') }}";
          }
          {
            name = "Tursensor Last Changed";
            state = "{{ relative_time(states.binary_sensor.tursensor_opening.last_changed) }}";
          }
          {
            name = "Weather Wind Gust";
            state = "{{ states('sensor.openweathermap_windboengeschwindigkeit') | float(0) }}";
            unit_of_measurement = "km/h";
            state_class = "measurement";
          }
        ];
      }
    ];
  };
}
