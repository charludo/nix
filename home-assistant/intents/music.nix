{ config, lib, ... }:
let
  e = config.hass.entities;
  player = e.media_player.alle;

  playMA = mediaType: mediaId: {
    action = "music_assistant.play_media";
    target.entity_id = player;
    data = {
      media_id = mediaId;
      media_type = mediaType;
    };
  };
  playPlaylist = name: [ (playMA "playlist" name) ];

  silent = lib.ha.voice.silentAction;
  ack = lib.ha.voice.acknowledgeAction;
in
{
  hass.voice.intents = {
    Musik_An = silent {
      sentences = [
        "(Spiele|Spiel|Starte) [etwas|ein bisschen|irgendwelche|zufällige] Musik"
        "Musik (an|abspielen|starten)"
      ];
      script = {
        action = playPlaylist "500 random tracks (from library)";
        speech.text = "Spiele 500 zufällige Titel.";
      };
    };

    Musik_Fortsetzen = silent {
      sentences = [
        "Musik (fortsetzen|weiter)"
        "(Mache|Setze) Musik fort"
        "(Fortsetzen|Weiter abspielen|Weiterspielen|Spiel weiter)"
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

    Musik_Pause = silent {
      sentences = [
        "(Pausiere|Stoppe) die Musik"
        "Musik (pausieren|anhalten|stoppen|aus)"
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

    Musik_Naechster = silent {
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

    Musik_ShuffleAn = ack {
      sentences = [
        "(Shuffle|Mischen|Zufallswiedergabe) [an|ein|aktivieren]"
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

    Musik_ShuffleAus = ack {
      sentences = [
        "(Shuffle|Mischen|Zufallswiedergabe) (aus|deaktivieren)"
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

    Musik_LoopAn = ack {
      sentences = [
        "(Wiederholung|Wiederholen) [an|ein|aktivieren]"
      ];
      script = {
        action = [
          {
            action = "media_player.repeat_set";
            target.entity_id = player;
            data.repeat = "all";
          }
        ];
        speech.text = "Wiederholen aktiviert.";
      };
    };

    Musik_LoopAus = ack {
      sentences = [
        "(Wiederholung|Wiederholen) (aus|deaktivieren)"
      ];
      script = {
        action = [
          {
            action = "media_player.repeat_set";
            target.entity_id = player;
            data.repeat = "off";
          }
        ];
        speech.text = "Wiederholen deaktiviert.";
      };
    };

    Musik_PlayerNeustart = {
      sentences = [
        "(Player|Spieler|Sonos) (neu starten|neustarten|resetten)"
      ];
      script = {
        action = [ { action = e.script.sonos_reset; } ];
        speech.text = "Player wird neu gestartet.";
      };
    };

    Musik_ZufaelligesAlbum = silent {
      sentences = [
        "[Spiele|Spiel] [ein] (zufälliges Album|Zufallsalbum)"
      ];
      script = {
        action = playPlaylist "Random Album (from library)";
        speech.text = "Spiele ein zufälliges Album.";
      };
    };

    Musik_ZufaelligerKuenstler = silent {
      sentences = [
        "(Spiele|Spiel) [einen] (zufälligen|zufälliger) (Künstler|Artist)"
      ];
      script = {
        action = playPlaylist "Random Artist (from library)";
        speech.text = "Spiele einen zufälligen Künstler.";
      };
    };

    Musik_NeueMusik = silent {
      sentences = [
        "(Spiele|Spiel) ([die] neue[sten|n]|kürzlich hinzugefügte) (Musik|Tracks|Titel|Lieder)"
      ];
      script = {
        action = playPlaylist "Recently added tracks";
        speech.text = "Spiele kürzlich hinzugefügte Musik.";
      };
    };

    Musik_KuerzlichGespielt = silent {
      sentences = [
        "(Spiele|Spiel) [die ]zuletzt (gehörten|gespielten) (Titel|Lieder|Tracks)"
        "Spiel (die|den) selben Song[s] nochmal"
      ];
      script = {
        action = playPlaylist "Recently played tracks";
        speech.text = "Spiele zuletzt gehörte Titel.";
      };
    };

    Musik_Playlist = {
      sentences = [
        "(Spiele|Spiel|Starte) die Playlist {mass_playlist}"
      ];
      script = {
        action = [ (playMA "playlist" "{{ mass_playlist }}") ];
        speech.text = "Spiele die Playlist {{ mass_playlist }}.";
      };
    };

    Musik_Album = {
      sentences = [
        "(Spiele|Spiel|Starte) das Album {mass_album}"
      ];
      script = {
        action = [ (playMA "album" "{{ mass_album }}") ];
        speech.text = "Spiele das Album {{ mass_album }}.";
      };
    };

    Musik_Genre = {
      sentences = [
        "(Spiele|Spiel|Starte) {mass_genre} (Musik|Lieder)"
        "(Spiele|Spiel|Starte) [die ]Musikrichtung {mass_genre}"
      ];
      script = {
        action = [
          {
            action = "music_assistant.play_media";
            target.entity_id = player;
            data.media_id = "{{ mass_genre }}";
          }
        ];
        speech.text = "Spiele {{mass_genre}} Musik.";
      };
    };

    Musik_Kuenstler = {
      sentences = [
        "(Spiele|Spiel) (was|etwas|Musik|etwas Musik) von {mass_artist}"
      ];
      script = {
        action = [ (playMA "artist" "{{ mass_artist }}") ];
        speech.text = "Spiele Musik von {{ mass_artist }}.";
      };
    };

    Musik_Song = silent {
      sentences = [
        "(Spiele|Spiel|Starte) (das|den) (Lied|Stück|Song) {mass_track}"
      ];
      script = {
        action = [ (playMA "track" "{{ mass_track }}") ];
        speech.text = "Spiele {{ mass_track }}.";
      };
    };

    Musik_SongVonKuenstler = silent {
      sentences = [
        "(Spiele|Spiel|Starte) [das|den] [Lied|Stück|Song] {mass_track} von {mass_artist}"
      ];
      script = {
        action = [
          {
            action = "music_assistant.play_media";
            target.entity_id = player;
            data = {
              media_id = "{{ mass_track }}";
              media_type = "track";
              artist = "{{ mass_artist }}";
            };
          }
        ];
        speech.text = "Spiele {{ mass_track }} von {{ mass_artist }}.";
      };
    };
  };
}
