{ ... }:
{
  hass.voice.intents = {
    TV_Hell = [
      "[Mache|Setze|Stelle] [den|das] (TV|Fernseher|Bild|Bildschirm) hell[er]"
      "[Fernseher] Tagmodus"
    ];
    TV_Dunkel = [
      "[Mache|Setze|Stelle] [den|das] (TV|Fernseher|Bild|Bildschirm) (dunkel|dunkler)"
      "[Fernseher] Nachtmodus"
    ];
  };

  hass.voice.intent_scripts = {
    TV_Hell = {
      action = [ { action = "rest_command.lgtv_picture_day"; } ];
      speech.text = "Bild ist jetzt hell.";
    };
    TV_Dunkel = {
      action = [ { action = "rest_command.lgtv_picture_night"; } ];
      speech.text = "Bild ist jetzt dunkel.";
    };
  };
}
