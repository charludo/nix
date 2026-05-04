{ ... }:
{
  hass.voice.intents = {
    UhrZeit = [
      "Wie (spät|viel Uhr) ist es"
      "Wie viel Uhr ist es"
      "Wie spät ist es"
    ];
    Datum = [
      "(Welches|Was für ein) Datum (haben wir|ist heute)"
      "Was ist heute für ein Datum"
    ];
    Wochentag = [
      "Welcher (Tag|Wochentag) ist heute"
      "Was ist heute für ein Tag"
    ];
  };

  hass.voice.intent_scripts = {
    UhrZeit.speech.text = "Es ist {{ now().strftime('%H:%M') }} Uhr.";
    Datum.speech.text = ''
      Heute ist der {{ now().day }}. {{ ['Januar','Februar','März','April','Mai','Juni','Juli','August','September','Oktober','November','Dezember'][now().month - 1] }} {{ now().year }}.
    '';
    Wochentag.speech.text = ''
      Heute ist {{ ['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'][now().weekday()] }}.
    '';
  };
}
