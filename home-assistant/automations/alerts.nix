{ config, lib, ... }:
let
  e = config.hass.entities;
  inherit (lib.ha) lowBatteryThreshold;

  notify =
    target:
    {
      title,
      message,
    }:
    {
      action = target;
      data = { inherit title message; };
    };

  notifyBoth = msg: [
    (notify e.person.charlotte.notify msg)
    (notify e.person.marie.notify msg)
  ];

  # Wind thresholds in km/h (both stations report km/h).
  windSpeedThreshold = 32; # sustained wind, live measurement
  gustThreshold = 40; # gusts, live measurement
  forecastWindThreshold = 50; # peak predicted wind over the next 12h
  forecastHorizon = 2; # number of hourly forecast entries to scan

  # Peak hourly forecast wind speed over the next `forecastHorizon` hours,
  # or 0 if no forecast is available. Shared by the trigger and the message.
  forecastPeakWind = ''
    {% set hours = (state_attr('${e.sensor.openweathermap_forecast_hourly}', 'forecast') or [])[:${toString forecastHorizon}] %}
    {% set speeds = hours | map(attribute='wind_speed', default=0) | map('float', 0) | list %}
    {% set peak = (speeds | max) if speeds else 0 %}
  '';
in
{
  hass.automations = {
    warnung_temperatur_gewachshaus = {
      alias = "Warnung Temperatur Gewächshaus";
      mode = "single";
      trigger = [
        {
          platform = "numeric_state";
          entity_id = e.sensor.thermometer_gewachshaus.temperature;
          below = 0;
          for.minutes = 20;
        }
      ];
      action = [
        (notify e.person.charlotte.notify {
          title = "Temperaturwarnung";
          message = "Extremtemperatur im Gewächshaus";
        })
      ];
    };

    luftfeuchtigkeit_badezimmer = {
      alias = "Luftfeuchtigkeit Badezimmer";
      mode = "single";
      trigger = [
        {
          platform = "numeric_state";
          entity_id = e.sensor.thermometer_badezimmer.humidity;
          above = 90;
          for.hours = 1;
        }
      ];
      action = notifyBoth {
        title = "Luftfeuchtigkeit im Badezimmer zu hoch";
        message = "Aufhören zu Duschen und Fenster aufmachen! 😡";
      };
    };

    temperatur_serverschrank = {
      alias = "Temperatur Serverschrank Warnung";
      mode = "single";
      trigger = [
        {
          platform = "numeric_state";
          entity_id = e.sensor.thermometer_serverschrank.temperature;
          above = 40;
          for.minutes = 5;
        }
      ];
      action = notifyBoth {
        title = "Was da los?!";
        message = "Hohe Temperatur im Serverschrank";
      };
    };

    luftfeuchtigkeit_wohnbereich = {
      alias = "Luftfeuchtigkeit Wohnbereich";
      mode = "single";
      trigger = [
        {
          platform = "numeric_state";
          entity_id = [
            e.sensor.thermometer_wohnzimmer.humidity
            e.sensor.thermometer_schlafzimmer.humidity
            e.sensor.thermometer_buro.humidity
          ];
          above = 70;
          for.minutes = 20;
        }
      ];
      action = notifyBoth {
        title = "Luftfeuchtigkeit im Wohnbereich zu hoch";
        message = "Zeit zu Lüften!";
      };
    };

    tursensor_alarm = {
      alias = "Türsensor Alarm";
      mode = "single";
      trigger = [
        {
          platform = "state";
          entity_id = e.binary_sensor.tursensor.opening;
          to = "on";
          for.seconds = 3;
        }
      ];
      condition = [
        {
          condition = "state";
          entity_id = e.input_boolean.turalarm;
          state = "on";
        }
      ];
      action =
        notifyBoth {
          title = "Wohnungstür ist seit 3 Sekunden offen";
          message = "WOHNUNGSTÜR WURDE GEÖFFNET";
        }
        ++ [
          {
            action = "input_boolean.turn_on";
            target.entity_id = e.input_boolean.turalarm_persistent;
          }
        ];
    };

    wind_wetterstation = {
      alias = "Windwarnung Wetterstation";
      mode = "single";
      trigger = [
        {
          platform = "numeric_state";
          entity_id = e.sensor.wetterstation.wind_speed;
          above = windSpeedThreshold;
          for.minutes = 5;
        }
        {
          platform = "numeric_state";
          entity_id = e.sensor.wetterstation.gust_speed;
          above = gustThreshold;
          for.minutes = 1;
        }
      ];
      action = notifyBoth {
        title = "Starker Wind";
        message = ''
          Aktuell {{ states('${e.sensor.wetterstation.wind_speed}') }} km/h, Böen bis {{ states('${e.sensor.wetterstation.gust_speed}') }} km/h.
          Gewächshaus zu machen!
        '';
      };
    };

    wind_vorhersage = {
      alias = "Windwarnung Vorhersage (OpenWeatherMap)";
      mode = "single";
      trigger = [
        {
          platform = "template";
          value_template = ''
            ${forecastPeakWind}
            {{ peak > ${toString forecastWindThreshold} }}
          '';
          for.minutes = 5;
        }
      ];
      action = notifyBoth {
        title = "Starker Wind vorhergesagt";
        message = ''
          ${forecastPeakWind}
          In den nächsten ${toString forecastHorizon} Stunden bis zu {{ '%.0f' | format(peak) }} km/h Wind vorhergesagt.
          Gewächshaus zu machen!
        '';
      };
    };

    zigbee_low_battery = {
      alias = "Zigbee niedriger Akku";
      mode = "single";
      trigger = [
        {
          platform = "numeric_state";
          entity_id = e.sensor.zigbee_min_battery;
          below = lowBatteryThreshold;
          for.minutes = 5;
        }
      ];
      action = notifyBoth {
        title = "Zigbee: Akku schwach";
        message = ''
          {% set ns = namespace(names=[]) %}
          {%- for s in expand('${e.sensor.zigbee_min_battery}') -%}
            {%- if s.state not in ['unknown', 'unavailable'] and (s.state | float(100)) < ${toString lowBatteryThreshold} -%}
              {%- set ns.names = ns.names + [s.name + ' (' + s.state + '%)'] -%}
            {%- endif -%}
          {%- endfor -%}
          Niedriger Akku: {{ ns.names | join(', ') }}
        '';
      };
    };
  };
}
