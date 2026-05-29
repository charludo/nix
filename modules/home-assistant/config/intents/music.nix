{ config, ... }:
let
  e = config.hass.entities;
  player = e.media_player.alle;

  playPlaylist = name: [
    {
      action = "music_assistant.play_media";
      target.entity_id = player;
      data = {
        media_id = name;
        media_type = "playlist";
      };
    }
  ];
in
{
  hass.voice.intents = {
    MusikAn = {
      sentences = [
        "(Spiele|Spiel|Starte) [Musik|die Musik]"
        "Musik (an|abspielen|starten)"
      ];
      script = {
        action = playPlaylist "500 random tracks (from library)";
        speech.text = "Spiele 500 zufällige Titel.";
      };
    };

    Musik_Fortsetzen = {
      sentences = [
        "Musik fortsetzen"
        "(Mache|Setze) Musik fort"
        "(Fortsetzen|Weiter abspielen|Weiterspielen)"
      ];
      script = {
        action = [
          {
            action = "media_player.media_play";
            target.entity_id = player;
          }
        ];
        speech.text = "Wird fortgesetzt.";
      };
    };

    Musik_Pause = {
      sentences = [
        "(Pausiere|Stoppe|Anhalten) [die Musik]"
        "Musik (pausieren|anhalten|stoppen)"
        "Pause"
      ];
      script = {
        action = [
          {
            action = "media_player.media_pause";
            target.entity_id = player;
          }
        ];
        speech.text = "Pausiert.";
      };
    };

    Musik_Naechster = {
      sentences = [
        "(Nächster|Nächstes) (Titel|Song|Lied)"
        "Skip"
        "Weiter"
      ];
      script = {
        action = [
          {
            action = "media_player.media_next_track";
            target.entity_id = player;
          }
        ];
        speech.text = "Nächster Titel.";
      };
    };

    Musik_ShuffleAn = {
      sentences = [
        "Shuffle (an|ein|aktivieren)"
        "Mischen (an|ein|aktivieren)"
        "Zufallswiedergabe (an|ein|aktivieren)"
      ];
      script = {
        action = [
          {
            action = "media_player.shuffle_set";
            target.entity_id = player;
            data.shuffle = true;
          }
        ];
        speech.text = "Shuffle aktiviert.";
      };
    };

    Musik_ShuffleAus = {
      sentences = [
        "Shuffle (aus|ab|deaktivieren)"
        "Mischen (aus|ab|deaktivieren)"
        "Zufallswiedergabe (aus|ab|deaktivieren)"
      ];
      script = {
        action = [
          {
            action = "media_player.shuffle_set";
            target.entity_id = player;
            data.shuffle = false;
          }
        ];
        speech.text = "Shuffle deaktiviert.";
      };
    };

    Musik_PlayerNeustart = {
      sentences = [
        "(Player|Spieler|Sonos) (neu starten|neustarten|resetten)"
        "Restart Player"
      ];
      script = {
        action = [ { action = e.script.sonos_reset; } ];
        speech.text = "Player wird neu gestartet.";
      };
    };

    Musik_ZufaelligesAlbum = {
      sentences = [
        "(Spiele|Spiel) [ein ]zufälliges Album"
        "Zufälliges Album"
        "Random Album"
      ];
      script = {
        action = playPlaylist "Random Album (from library)";
        speech.text = "Spiele ein zufälliges Album.";
      };
    };

    Musik_ZufaelligerKuenstler = {
      sentences = [
        "(Spiele|Spiel) [einen ]zufälligen (Künstler|Artist)"
        "Zufälliger (Künstler|Artist)"
        "Random Artist"
      ];
      script = {
        action = playPlaylist "Random Artist (from library)";
        speech.text = "Spiele einen zufälligen Künstler.";
      };
    };

    Musik_NeueMusik = {
      sentences = [
        "(Spiele|Spiel) [die ]neue[sten|n] (Musik|Tracks|Titel|Lieder)"
        "(Spiele|Spiel) [die ]Playlist (neue Musik|Neue Tracks|Recently Added)"
        "Recently Added"
      ];
      script = {
        action = playPlaylist "Recently added tracks";
        speech.text = "Spiele neue Musik.";
      };
    };

    Musik_KuerzlichGespielt = {
      sentences = [
        "(Spiele|Spiel) [die ]zuletzt (gehörten|gespielten) (Titel|Lieder|Tracks)"
        "Recently Played"
        "Spiel die selben Songs nochmal"
      ];
      script = {
        action = playPlaylist "Recently played tracks";
        speech.text = "Spiele zuletzt gehörte Titel.";
      };
    };

    Musik_Playlist = {
      sentences = [
        "(Spiele|Spiel|Starte) [die ]Playlist {playlist}"
        "Playlist[e] {playlist}"
      ];
      lists.playlist.values = [
        "Bridgerton Pop"
        "NieR"
        "Philharmonix"
        "Sea Shanties"
      ];
      script = {
        action = [
          {
            action = "music_assistant.play_media";
            target.entity_id = player;
            data = {
              media_id = "{{ playlist }}";
              media_type = "playlist";
            };
          }
        ];
        speech.text = "Spiele Playlist {{ playlist }}.";
      };
    };
  };
}
