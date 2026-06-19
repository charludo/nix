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

  slots = map (
    t:
    if builtins.isString t then
      {
        time = t;
        degrees = null;
      }
    else
      t
  ) cfg.times;
  heatSlots = lib.filter (s: s.degrees != null) slots;
  heatThresholds =
    "{"
    + lib.concatStringsSep ", " (map (s: "'${timeSlug s.time}': ${toString s.degrees}") heatSlots)
    + "}";
  heatSlugList = "[" + lib.concatStringsSep ", " (map (s: "'${timeSlug s.time}'") heatSlots) + "]";
in
{
  options.hass.bewasserung = {
    times = lib.mkOption {
      type = lib.types.listOf (
        lib.types.either lib.types.str (
          lib.types.submodule {
            options = {
              time = lib.mkOption {
                type = lib.types.str;
                description = "Slot time as \"HH:MM\".";
              };
              degrees = lib.mkOption {
                type = lib.types.nullOr (lib.types.either lib.types.int lib.types.float);
                default = null;
                description = ''
                  Optional heat override in °C. ~10 min before the slot (5 min before the pump turns on)
                  the slot's toggle is switched on if the outdoor temperature in the prior exceeded this value in the past 90min
                '';
              };
            };
          }
        )
      );
      default = [ ];
      example = [
        "07:00"
        {
          time = "13:00";
          degrees = 28;
        }
        "19:00"
      ];
      description = "For each slot the pump turns on 5 minutes before and off 5 minutes after, rain not forbidding";
    };
  };

  config = lib.mkIf (cfg.times != [ ]) {
    hass.devices.input_booleans = lib.listToAttrs (
      map (
        s:
        lib.nameValuePair "bewasserung_zeit_${timeSlug s.time}" {
          name = "Bewässerung ${s.time}";
          icon = "mdi:water-outline";
          area = e.area.terrasse.name;
        }
      ) slots
      ++ map (
        s:
        lib.nameValuePair "bewasserung_zeit_${timeSlug s.time}_auto" {
          name = "Bewässerung ${s.time} (Auto)";
          icon = "mdi:water-circle";
        }
      ) heatSlots
    );

    hass.automations = {
      wasserpumpe_an = {
        alias = "Wasserpumpe an";
        mode = "single";
        trigger = map (s: {
          at = shiftTime s.time (-5);
          trigger = "time";
          id = timeSlug s.time;
        }) slots;
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
        trigger = map (s: {
          at = shiftTime s.time 5;
          trigger = "time";
          id = timeSlug s.time;
        }) slots;
        action = [
          {
            action = "switch.turn_off";
            target.entity_id = e.switch.steckdose_wasserpumpe.switch;
          }
          {
            "if" = [
              {
                # Only auto-disable a heat slot that was auto-enabled by the heat
                # override; a slot the user enabled manually stays on.
                condition = "template";
                value_template = "{{ trigger.id in ${heatSlugList} and is_state('input_boolean.bewasserung_zeit_' ~ trigger.id ~ '_auto', 'on') }}";
              }
            ];
            "then" = [
              {
                action = "input_boolean.turn_off";
                target.entity_id = "{{ 'input_boolean.bewasserung_zeit_' ~ trigger.id }}";
              }
              {
                action = "input_boolean.turn_off";
                target.entity_id = "{{ 'input_boolean.bewasserung_zeit_' ~ trigger.id ~ '_auto' }}";
              }
            ];
          }
        ];
      };
    }
    // lib.optionalAttrs (heatSlots != [ ]) {
      wasserpumpe_hitze = {
        alias = "Wasserpumpe Hitze-Vorabaktivierung";
        mode = "single";
        trigger = map (s: {
          at = shiftTime s.time (-10);
          trigger = "time";
          id = timeSlug s.time;
        }) heatSlots;
        action = [
          {
            "if" = [
              {
                # Heat threshold exceeded AND the slot is still off — if the user
                # already manually enabled it, do nothing so it is not marked auto.
                condition = "template";
                value_template = ''
                  {% set thr = ${heatThresholds}.get(trigger.id, -999) %}
                  {{ (states('${e.sensor.max_temp_90min}') | float(-999)) > thr
                     and is_state('input_boolean.bewasserung_zeit_' ~ trigger.id, 'off') }}
                '';
              }
            ];
            "then" = [
              {
                # Remember this slot was auto-enabled, so wasserpumpe_aus knows it
                # may auto-disable it again (manual enables stay untouched).
                action = "input_boolean.turn_on";
                target.entity_id = "{{ 'input_boolean.bewasserung_zeit_' ~ trigger.id ~ '_auto' }}";
              }
              {
                action = "input_boolean.turn_on";
                target.entity_id = "{{ 'input_boolean.bewasserung_zeit_' ~ trigger.id }}";
              }
              {
                action = e.person.charlotte.notify;
                data.message = ''
                  Hitze: Bewässerung {{ trigger.id | replace('_', ':') }} vorgemerkt ({{ '%.0f' | format(states('${e.sensor.max_temp_90min}') | float(0)) }}°C). Pumpe startet in 5 min.
                '';
              }
            ];
          }
        ];
      };
    };
  };
}
