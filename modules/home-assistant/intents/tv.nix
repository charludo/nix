{ ... }:
{
  hass.voice.intents = {
    TV_Hell = [
      "(Mache|Setze|Stelle) (den TV|den Fernseher|das Bild) hell"
      "(TV|Fernseher|Bild|Bildschirm) hell"
      "(Mache|Stelle) (TV|Fernseher) heller"
      "(Mache|Stelle) (TV|Fernseher) auf Tag"
      "Tagmodus"
    ];
    TV_Dunkel = [
      "(Mache|Setze|Stelle) (den TV|den Fernseher|das Bild) dunkel"
      "(TV|Fernseher|Bild|Bildschirm) dunkel"
      "(Mache|Stelle) (TV|Fernseher) dunkler"
      "(Mache|Stelle) (TV|Fernseher) auf Nacht"
      "(Nachtmodus|Kinomodus)"
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
