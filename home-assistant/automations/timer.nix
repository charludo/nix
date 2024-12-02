{
  config,
  lib,
  pkgs,
  ...
}:
let
  e = config.hass.entities;
  fallback = e.media_player.living_room;

  timerPath = config.hass.voice.sounds.timer;
  timerUrl = if timerPath == null then null else "/local/sounds/${baseNameOf timerPath}";
  timerDurationMs = lib.ha.soundDurationMs pkgs timerPath;
in
{
  hass.automations.timer_finished_announcement = {
    alias = "Timer finished, announce on speakers";
    mode = "parallel";
    trigger = map (timerId: {
      platform = "event";
      event_type = "timer.finished";
      event_data.entity_id = timerId;
    }) (builtins.attrValues e.timer);
    variables.area_to_target = lib.ha.voice.satelliteAreaToTarget config;
    action = [
      {
        variables.target = ''
          {% set slug = trigger.event.data.entity_id | replace("timer.", "") %}
          {% set area = states('input_text.' ~ slug ~ '_area') %}
          {{ area_to_target.get(area) or '${fallback}' }}
        '';
      }
      {
        action = "media_player.volume_mute";
        target.entity_id = "{{ target }}";
        data.is_volume_muted = false;
      }
    ]
    ++ lib.optionals (timerUrl != null) [
      {
        action = "media_player.play_media";
        target.entity_id = "{{ target }}";
        data = {
          announce = true;
          media_content_id = timerUrl;
          media_content_type = "music";
        };
      }
      { delay.milliseconds = timerDurationMs; }
    ]
    ++ [
      {
        action = "tts.speak";
        target.entity_id = "tts.piper";
        data = {
          media_player_entity_id = "{{ target }}";
          message = "Der Timer {{ state_attr(trigger.event.data.entity_id, 'friendly_name') }} ist abgelaufen.";
        };
      }
    ];
  };
}
