{ config, lib, ... }:
let
  silent = lib.ha.voice.silentAction;
  unmute = lib.ha.voice.unmuteSatellite {
    inherit config;
    fallback = config.hass.news.fallbackTarget;
  };
  actions = config.hass.news.actions;
in
{
  hass.voice.intents = {
    NewsTagesschau = silent (unmute {
      sentences = [
        "[Spiele|Spiel|Starte] [die] Tagesschau [in (hundert|100) Sekunden]"
      ];
      script = {
        action = actions.tagesschau;
        speech.text = "Von der Tagesschau.";
      };
    });

    NewsWDRAktuell = silent (unmute {
      sentences = [
        "[Spiele|Spiel|Starte] WDR (Aktuell|aktuell)"
      ];
      script = {
        action = actions.wdrAktuell;
        speech.text = "Von WDR Aktuell.";
      };
    });

    NewsTaeglicheZusammenfassung = silent (unmute {
      sentences = [
        "[Spiele|Spiel|Starte] [die|meine] (Nachrichten|tägliche Zusammenfassung)"
      ];
      script = {
        action = actions.summary;
        speech.text = "Hier ist deine tägliche Zusammenfassung.";
      };
    });
  };
}
