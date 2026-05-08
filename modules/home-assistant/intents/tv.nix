{ ... }:
{
  hass.voice = {
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
  };
}
