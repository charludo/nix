{ config, ... }:
let
  e = config.hass.entities;
in
{
  hass.automations.timer_finished_announcement = {
    alias = "Timer finished — announce on speakers";
    mode = "parallel";
    trigger = map (timerId: {
      platform = "event";
      event_type = "timer.finished";
      event_data.entity_id = timerId;
    }) (builtins.attrValues e.timer);
    action = [
      {
        action = "tts.speak";
        target.entity_id = "tts.piper";
        data = {
          media_player_entity_id = e.media_player.alle;
          message = "Der Timer {{ state_attr(trigger.event.data.entity_id, 'friendly_name') }} ist abgelaufen.";
        };
      }
    ];
  };
}
