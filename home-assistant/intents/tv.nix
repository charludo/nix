{ config, lib, ... }:
let
  tv = config.hass.entities.media_player.lg_c4;
  ack = lib.ha.voice.acknowledgeAction;
  silent = lib.ha.voice.silentAction;
in
{
  hass.voice.intents = {
    TV_Hell = ack {
      sentences = [
        "[Mach] [den|das] (Fernseher|Bild) hell[er]"
      ];
      script = {
        action = [ { action = "rest_command.lgtv_picture_day"; } ];
        speech.text = "Bild ist jetzt hell.";
      };
    };

    TV_Dunkel = ack {
      sentences = [
        "[Mach] [den|das] (Fernseher|Bild) (dunkel|dunkler)"
      ];
      script = {
        action = [ { action = "rest_command.lgtv_picture_night"; } ];
        speech.text = "Bild ist jetzt dunkel.";
      };
    };

    TV_Aus = ack {
      sentences = [
        "(Schalt|Mache) den Fernseher aus"
        "Fernseher (aus|ausschalten)"
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

    TV_Stumm = silent {
      sentences = [
        "Fernseher (stumm|stummschalten|leise)"
        "(Mach|Schalt) den Fernseher (stumm|leise)"
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
