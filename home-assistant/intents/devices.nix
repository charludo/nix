{ config, lib, ... }:
let
  e = config.hass.entities;
  ack = lib.ha.voice.acknowledgeAction;

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

  spokenName = "state_attr(geraet, 'friendly_name') or Gerät";
in
{
  hass.voice.intents = {
    DeviceTurnOn = ack {
      sentences = [
        "[Schalte |Mach ][den | die | das ]{geraet} (an|ein)[schalten|machen]"
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
        "[Schalte |Mach ][den | die | das ]{geraet} aus[schalten]"
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

    DeviceStatus = {
      sentences = [
        "Ist [der |die |das ]{geraet} (an|aus)[geschaltet]"
      ];
      lists.geraet.values = geraetSlotValues;
      script.speech.text = "{{ ${spokenName} }} ist aktuell {{ 'an' if is_state(geraet, 'on') else 'aus' }}.";
    };
  };
}
