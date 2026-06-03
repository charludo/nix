{ config, lib, ... }:
let
  e = config.hass.entities;
  cfg = config.hass.bewasserung;

  timeSlug = lib.replaceStrings [ ":" ] [ "_" ];
  shiftTime =
    hhmm: delta:
    let
      pad = n: if n < 10 then "0${toString n}" else toString n;
      parts = lib.splitString ":" hhmm;
      total =
        lib.toIntBase10 (builtins.elemAt parts 0) * 60 + lib.toIntBase10 (builtins.elemAt parts 1) + delta;
      wrapped =
        if total < 0 then
          total + 1440
        else if total >= 1440 then
          total - 1440
        else
          total;
    in
    "${pad (wrapped / 60)}:${pad (wrapped - (wrapped / 60) * 60)}:00";
in
{
  options.hass.bewasserung = {
    times = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "07:00"
        "13:00"
        "19:00"
      ];
      description = "For each slot the pump turns on 5 minutes before and off 5 minutes after, rain not forbidding";
    };
  };

  config = lib.mkIf (cfg.times != [ ]) {
    hass.devices.input_booleans = lib.listToAttrs (
      map (
        t:
        lib.nameValuePair "bewasserung_zeit_${timeSlug t}" {
          name = "Bewässerung ${t}";
          icon = "mdi:water-outline";
          area = e.area.terrasse.name;
        }
      ) cfg.times
    );

    hass.automations = {
      wasserpumpe_an = {
        alias = "Wasserpumpe an";
        mode = "single";
        trigger = map (t: {
          at = shiftTime t (-5);
          trigger = "time";
          id = timeSlug t;
        }) cfg.times;
        action = [
          {
            "if" = [
              {
                condition = "template";
                value_template = "{{ is_state('input_boolean.bewasserung_zeit_' ~ trigger.id, 'on') }}";
              }
            ];
            "then" = [
              {
                "if" = [
                  {
                    condition = "or";
                    conditions = [
                      {
                        condition = "numeric_state";
                        entity_id = e.sensor.cumulative_rain_8h;
                        above = 4;
                      }
                      {
                        condition = "numeric_state";
                        entity_id = e.sensor.cumulative_rain_24h;
                        above = 10;
                      }
                    ];
                  }
                ];
                "then" = [
                  {
                    action = e.person.charlotte.notify;
                    data.message = ''
                      {% set r8 = states('${e.sensor.cumulative_rain_8h}') | float(0) %}
                      {% if r8 > 4 %}
                        Pumpe nicht aktiviert: {{ '%.1f' | format(r8) }}mm Regen in den letzten 8h.
                      {% else %}
                        Pumpe nicht aktiviert: {{ '%.1f' | format(states('${e.sensor.cumulative_rain_24h}') | float(0)) }}mm Regen in den letzten 24h.
                      {% endif %}
                    '';
                  }
                  {
                    action = "input_boolean.turn_on";
                    target.entity_id = e.input_boolean.pumpe_uebersprungen;
                  }
                ];
                "else" = [
                  {
                    action = "switch.turn_on";
                    target.entity_id = e.switch.steckdose_wasserpumpe.switch;
                  }
                  {
                    "if" = [
                      {
                        condition = "state";
                        entity_id = e.input_boolean.pumpe_uebersprungen;
                        state = "on";
                      }
                    ];
                    "then" = [
                      {
                        action = e.person.charlotte.notify;
                        data.message = "Pumpe reaktiviert.";
                      }
                      {
                        action = "input_boolean.turn_off";
                        target.entity_id = e.input_boolean.pumpe_uebersprungen;
                      }
                    ];
                  }
                ];
              }
            ];
          }
        ];
      };

      wasserpumpe_aus = {
        alias = "Wasserpumpe aus";
        mode = "single";
        trigger = map (t: {
          at = shiftTime t 5;
          trigger = "time";
        }) cfg.times;
        action = [
          {
            action = "switch.turn_off";
            target.entity_id = e.switch.steckdose_wasserpumpe.switch;
          }
        ];
      };
    };
  };
}
