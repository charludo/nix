{ config, lib, ... }:
let
  e = config.hass.entities;

  silent = lib.ha.voice.silentAction;
  unmute = lib.ha.voice.unmuteSatellite { inherit config; };

  sonosByRoom = {
    "Wohnzimmer" = e.media_player.living_room;
    "Büro" = e.media_player.office;
  };

  mkMuteSentences = room: [
    "(Lautsprecher|Sonos) im ${room} (stumm|aus)"
    "${room} (Lautsprecher|Sonos) (stumm|aus)"
  ];
  mkUnmuteSentences = room: [
    "(Lautsprecher|Sonos) im ${room} (an|laut)"
    "${room} (Lautsprecher|Sonos) (an|laut)"
  ];

  mkMuteIntent =
    entity: sentences:
    silent {
      inherit sentences;
      script = {
        action = lib.ha.voice.muteAction entity true;
        speech.text = "Stummgeschaltet.";
      };
    };

  mkUnmuteIntent =
    entity: sentences:
    silent {
      inherit sentences;
      script = {
        action = lib.ha.voice.muteAction entity false;
        speech.text = "Wieder laut.";
      };
    };

  setVolume = computeVolume: [
    {
      "if" = [
        {
          condition = "template";
          value_template = ''{{ area_to_target.get(preferred_area_id | default("")) is not none }}'';
        }
      ];
      "then" = [
        {
          action = "media_player.volume_set";
          target.entity_id = "{{ area_to_target[preferred_area_id] }}";
          data.volume_level = computeVolume;
        }
      ];
    }
  ];

  relativeVolume = op: ''
    {%- set t = area_to_target[preferred_area_id] -%}
    {%- set cur = (state_attr(t, 'volume_level') or 0.5) | float -%}
    {{ ${op} }}
  '';
in
{
  hass.voice.intents =
    (lib.foldlAttrs (
      acc: room: sonos:
      acc
      // {
        "Lautsprecher${lib.ha.mkTitleSlug room}Aus" = mkMuteIntent sonos (mkMuteSentences room);
        "Lautsprecher${lib.ha.mkTitleSlug room}An" = mkUnmuteIntent sonos (mkUnmuteSentences room);
      }
    ) { } sonosByRoom)
    // {
      MusikLautstaerke = silent (unmute {
        sentences = [ "Lautstärke {level}" ];
        lists.level.range = {
          from = 1;
          to = 10;
        };
        script.action = setVolume "{{ (level | int) / 10 }}";
      });

      MusikLauter = silent (unmute {
        sentences = [
          "Lauter"
          "Lautstärke (hoch|höher|hoeher)"
        ];
        script.action = setVolume (relativeVolume "[1.0, cur + 0.05] | min");
      });

      MusikLeiser = silent (unmute {
        sentences = [
          "Leiser"
          "Lautstärke (runter|niedriger)"
        ];
        script.action = setVolume (relativeVolume "[0.0, cur - 0.05] | max");
      });

      StilleAlle = silent {
        sentences = [
          "[Halt die ](Klappe|Fresse)[ halten]"
          "Sei (still|ruhig)[ jetzt]"
          "Ruhe"
          "Aus"
        ];
        script.action = [
          {
            action = "tts_relay.silence";
            data.entity_id = [
              e.media_player.living_room
              e.media_player.office
            ];
          }
        ];
      };
    };
}
