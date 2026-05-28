{ config, ... }:
let
  tv = config.hass.entities.media_player.lg_c4;
in
{
  hass.voice.intents = {
    TV_Hell = {
      sentences = [
        "[Mache|Setze|Stelle] [den|das] (TV|Fernseher|Bild|Bildschirm) hell[er]"
        "[Fernseher] Tagmodus"
      ];
      script = {
        action = [ { action = "rest_command.lgtv_picture_day"; } ];
        speech.text = "Bild ist jetzt hell.";
      };
    };

    TV_Dunkel = {
      sentences = [
        "[Mache|Setze|Stelle] [den|das] (TV|Fernseher|Bild|Bildschirm) (dunkel|dunkler)"
        "[Fernseher] Nachtmodus"
      ];
      script = {
        action = [ { action = "rest_command.lgtv_picture_night"; } ];
        speech.text = "Bild ist jetzt dunkel.";
      };
    };

    TV_Aus = {
      sentences = [
        "(Schalte|Mache) [den|das] (TV|Fernseher) aus"
        "(TV|Fernseher) (aus|ausschalten|abschalten)"
      ];
      script = {
        action = [
          {
            action = "media_player.turn_off";
            target.entity_id = tv;
          }
        ];
        speech.text = "Fernseher ausgeschaltet.";
      };
    };

    TV_Stumm = {
      sentences = [
        "(Stumm|Stummschalten|Mute) [den|das] (TV|Fernseher)"
        "(TV|Fernseher) (stumm|stummschalten|leise|mute)"
        "(Mache|Stelle) [den|das] (TV|Fernseher) (stumm|leise)"
      ];
      script = {
        action = [
          {
            action = "media_player.volume_mute";
            target.entity_id = tv;
            data.is_volume_muted = "{{ not state_attr('${tv}', 'is_volume_muted') }}";
          }
        ];
        speech.text = "Fernseher stummgeschaltet.";
      };
    };
  };
}
