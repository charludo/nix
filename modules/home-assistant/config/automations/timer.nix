{ config, ... }:
let
  e = config.hass.entities;
in
{
  hass.automations.timer_finished_announcement = {
    alias = "Timer finished — announce on speakers";
    mode = "parallel";
    trigger = [
      {
        platform = "event";
        event_type = "timer.finished";
        event_data = { };
      }
    ];
    # Filter to our pool only; ignore Assist-managed voice timers etc.
    condition = [
      {
        condition = "template";
        value_template = ''
          {{ trigger.event.data.entity_id in ${builtins.toJSON (builtins.attrValues e.timer)} }}
        '';
      }
    ];
    action = [
      {
        action = "tts.speak";
        # Adjust to your TTS entity if it isn't named tts.piper.
        target.entity_id = "tts.piper";
        data = {
          media_player_entity_id = e.media_player.alle;
          message = "Der Timer {{ state_attr(trigger.event.data.entity_id, 'friendly_name') }} ist abgelaufen.";
        };
      }
    ];
  };
}
