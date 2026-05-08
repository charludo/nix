{ ... }:
{
  hass.voice = {
    Zeit_Uhrzeit = {
      sentences = [
        "Wie (spät|viel Uhr) ist es"
        "Wie viel Uhr ist es"
        "Wie spät ist es"
        "Uhrzeit"
      ];
      script.speech.text = "Es ist {{ now().strftime('%H:%M') }} Uhr.";
    };

    Zeit_Datum = {
      sentences = [
        "(Welches|Was für ein) Datum (haben wir|ist heute)"
        "Was ist heute für ein Datum"
        "Datum"
      ];
      script.speech.text = ''
        Heute ist {{ ['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'][now().weekday()] }}, der {{ now().day }}. {{ ['Januar','Februar','März','April','Mai','Juni','Juli','August','September','Oktober','November','Dezember'][now().month - 1] }} {{ now().year }}.
      '';
    };

    Zeit_Wochentag = {
      sentences = [
        "Welcher (Tag|Wochentag) ist heute"
        "Was ist heute für ein Tag"
        "[Wochen]Tag"
      ];
      script.speech.text = ''
        Heute ist {{ ['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'][now().weekday()] }}.
      '';
    };
  };
}
