{
  hass.voice.intents = {
    ZeitUhrzeit = {
      sentences = [
        "Wie (spät|viel Uhr) ist es"
        "Uhrzeit"
        "Woodland" # ok, sure thing buddy whisper
      ];
      script.speech.text = "Es ist {{ now().strftime('%H:%M') }}.";
    };

    ZeitDatum = {
      sentences = [
        "(Welches|Was für ein) Datum (haben wir|ist heute)"
        "Was ist [heute] das Datum"
        "Datum"
      ];
      script.speech.text = ''
        Heute ist {{ ['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'][now().weekday()] }}, der {{ now().day }}. {{ ['Januar','Februar','März','April','Mai','Juni','Juli','August','September','Oktober','November','Dezember'][now().month - 1] }} {{ now().year }}.
      '';
    };

    ZeitWochentag = {
      sentences = [
        "Welcher (Tag|Wochentag) ist heute"
        "Was ist heute für ein (Wochentag|Tag)"
        "Wochentag"
      ];
      script.speech.text = ''
        Heute ist {{ ['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'][now().weekday()] }}.
      '';
    };
  };
}
