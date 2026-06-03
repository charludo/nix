{ config, lib, ... }:
let
  e = config.hass.entities;
  ack = lib.ha.voice.acknowledgeAction;

  # Single source of truth for the on/off/status intents. `entity` is
  # the entity_id homeassistant.turn_on/off should target; `aliases`
  # are the spoken forms the slot matcher accepts. Speech responses
  # pull the spoken-back form from HA's friendly_name at runtime
  # (zha-reconciler sets it for ZHA devices; integration defaults
  # otherwise — e.g. the Xiaomi fan reads back as "Xiaomi Smart Fan").
  #
  # The slot is named `geraet` rather than `name` because `name` is
  # Hassil's builtin slot for the exposed-entity registry — a custom
  # `lists.name` collides with it and the builtin (no `out` field) wins
  # silently, which is why the in/out resolution did not survive the
  # first attempt.
  devices = [
    {
      entity = e.switch.steckdose_wasserpumpe.switch;
      aliases = [
        "Wasserpumpe"
        "Pumpe"
      ];
    }
    {
      entity = e.fan.xiaomi_smart_fan;
      aliases = [
        "Ventilator"
        "Lüfter"
      ];
    }
    {
      entity = e.light.strahler.light;
      aliases = [ "Strahler" ];
    }
    {
      entity = e.switch.steckdose_pflanzenlicht.switch;
      aliases = [
        "Pflanzlicht"
        "Pflanzenlicht"
      ];
    }
  ];

  geraetSlotValues = lib.concatMap (
    d:
    map (alias: {
      "in" = alias;
      out = d.entity;
    }) d.aliases
  ) devices;

  spokenName = ''state_attr(geraet, 'friendly_name') or geraet'';
in
{
  hass.voice.intents = {
    DeviceTurnOn = ack {
      sentences = [
        "[Schalte |Mach ][den | die | das ]{geraet} (an|ein)"
        "{geraet} (an|ein)[schalten]"
      ];
      lists.geraet.values = geraetSlotValues;
      script = {
        action = [
          {
            action = "homeassistant.turn_on";
            target.entity_id = "{{ geraet }}";
          }
        ];
        speech.text = "{{ ${spokenName} }} eingeschaltet.";
      };
    };

    DeviceTurnOff = ack {
      sentences = [
        "[Schalte |Mach ][den | die | das ]{geraet} aus"
        "{geraet} aus[schalten]"
      ];
      lists.geraet.values = geraetSlotValues;
      script = {
        action = [
          {
            action = "homeassistant.turn_off";
            target.entity_id = "{{ geraet }}";
          }
        ];
        speech.text = "{{ ${spokenName} }} ausgeschaltet.";
      };
    };

    # Status query stays on the voice path (no ack wrapper) — the
    # whole point is to hear the answer.
    DeviceStatus = {
      sentences = [
        "Ist [der |die |das ]{geraet} (an|aus)[geschaltet]"
      ];
      lists.geraet.values = geraetSlotValues;
      script.speech.text = "{{ ${spokenName} }} ist aktuell {{ 'an' if is_state(geraet, 'on') else 'aus' }}.";
    };
  };
}
