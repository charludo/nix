{ config, lib, ... }:
let
  e = config.hass.entities;
  cfg = config.hass.bewasserung;

  pad = n: if n < 10 then "0${toString n}" else toString n;

  parseTime =
    hhmm:
    let
      parts = lib.splitString ":" hhmm;
    in
    {
      h = lib.toIntBase10 (builtins.elemAt parts 0);
      m = lib.toIntBase10 (builtins.elemAt parts 1);
    };

  # Shift "HH:MM" by `delta` minutes (negative allowed); wraps mod 24h so a
  # window straddling midnight still produces a valid daily trigger.
  shiftTime =
    hhmm: delta:
    let
      p = parseTime hhmm;
      total = p.h * 60 + p.m + delta;
      modulo = a: b: a - (a / b) * b;
      wrapped = modulo ((modulo total 1440) + 1440) 1440;
    in
    "${pad (wrapped / 60)}:${pad (modulo wrapped 60)}:00";

  # "07:00" → "07_00"; used as both the per-slot input_boolean suffix
  # and the trigger.id, so the automation can look up the enable flag
  # for whichever slot fired without a per-slot duplicated branch.
  timeSlug = lib.replaceStrings [ ":" ] [ "_" ];

  slotBoolean = t: lib.nameValuePair "bewasserung_zeit_${timeSlug t}" {
    name = "Bewässerung ${t}";
    icon = "mdi:water-outline";
    area = e.areaName.terrasse;
  };

  # Same predicate as before the refactor (8h > 4mm OR 24h > 10mm). Kept as
  # a single attrset so both the rain-skip notify branch and the dashboard
  # could share the threshold in future without redefining it.
  rainSkip = {
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
  };
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
      description = ''
        Watering slots as "HH:MM". For each slot the pump turns on 5
        minutes before and off 5 minutes after, provided the wasserpumpe
        automation is on, the per-slot input_boolean is on, and the
        rain-skip thresholds aren't tripped.
      '';
    };
  };

  config = lib.mkIf (cfg.times != [ ]) {
    hass.devices.input_booleans = lib.listToAttrs (map slotBoolean cfg.times);

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
            # Per-slot enable check: trigger.id is the slot's slug, so
            # one templated lookup covers every slot.
            "if" = [
              {
                condition = "template";
                value_template = "{{ is_state('input_boolean.bewasserung_zeit_' ~ trigger.id, 'on') }}";
              }
            ];
            "then" = [
              {
                "if" = [ rainSkip ];
                "then" = [
                  {
                    action = e.persons.Charlotte.notify;
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
                        action = e.persons.Charlotte.notify;
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

      # Off runs unconditionally — if the slot was disabled or rain-skipped
      # the switch was never turned on, so turning it off is a no-op.
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
