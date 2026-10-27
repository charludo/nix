{
  config,
  lib,
  pkgs,
  ...
}:
let
  e = config.hass.entities;
  inherit (config.hass.voice) sounds ttsEntity;

  soundUrl = path: "/local/sounds/${baseNameOf path}";
  timerDurationMs = lib.ha.soundDurationMs pkgs sounds.timer;
in
{
  # Called by remembrance once per ring round, with the item's fields as
  # variables plus `round` (from 1). Plays the kind's sound on the Sonos of
  # the item's area; the first round also says what rang.
  hass.scripts.remembrance_ring = {
    alias = "Remembrance ring";
    icon = "mdi:bell-ring";
    mode = "parallel";
    fields = {
      kind.selector.text = { };
      label.selector.text = { };
      area.selector.area = { };
      duration.selector.number.mode = "box";
      round.selector.number.mode = "box";
    };
    sequence = [
      { variables.area_to_target = lib.ha.voice.satelliteAreaToTarget config; }
      {
        variables = {
          target = "{{ area_to_target.get(area | default('')) or '${e.media_player.living_room}' }}";
          text = "${lib.ha.voice.remembranceJinja}Der {{ timer_name({'label': label | default(none), 'duration': duration | default(0)}) }} ist abgelaufen.";
        };
      }
      {
        action = "media_player.volume_mute";
        target.entity_id = "{{ target }}";
        data.is_volume_muted = false;
      }
      {
        action = "media_player.play_media";
        target.entity_id = "{{ target }}";
        data = {
          announce = true;
          media_content_id = soundUrl sounds.timer;
          media_content_type = "music";
        };
      }
      {
        "if" = [
          {
            condition = "template";
            value_template = "{{ round | int(1) == 1 }}";
          }
        ];
        "then" = [
          { delay.milliseconds = timerDurationMs; }
          {
            action = "media_player.play_media";
            target.entity_id = "{{ target }}";
            data = {
              announce = true;
              media_content_id = "media-source://tts/${ttsEntity}?message={{ text | urlencode }}";
              media_content_type = "music";
            };
          }
        ];
      }
    ];
  };
}
