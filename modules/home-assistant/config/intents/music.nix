{ config, lib, ... }:
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

  # Music intents start audio on the same Sonos that tts_relay would
  # otherwise speak on; the speech would talk over the music. silentAction
  # drops the satellite-side audio while keeping the speech for the chat
  # path. Transport intents (pause/skip/shuffle) get acknowledgeAction —
  # a short blip is friendlier than no feedback at all.
  silent = lib.ha.voice.silentAction;
  ack = lib.ha.voice.acknowledgeAction;
in
{
  hass.voice.intents = {
    MusikAn = silent {
      sentences = [
        "(Spiele|Spiel|Starte) [Musik|die Musik]"
        "Musik (an|abspielen|starten)"
      ];
      script = {
        action = playPlaylist "500 random tracks (from library)";
        speech.text = "Spiele 500 zufällige Titel.";
      };
    };

    Musik_Fortsetzen = silent {
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

    Musik_Pause = silent {
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

    Musik_ShuffleAus = ack {
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

    Musik_ZufaelligesAlbum = silent {
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

    Musik_ZufaelligerKuenstler = silent {
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

    Musik_NeueMusik = silent {
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

    Musik_KuerzlichGespielt = silent {
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
        "(Spiele|Spiel|Starte) [die ]Playlist {mass_playlist}"
        "Playlist[e] {mass_playlist}"
      ];
      script = {
        action = [
          {
            action = "music_assistant.play_media";
            target.entity_id = player;
            data = {
              media_id = "{{ mass_playlist }}";
              media_type = "playlist";
            };
          }
        ];
        speech.text = "Spiele Playlist {{ mass_playlist }}.";
      };
    };

    Musik_Album = {
      sentences = [
        "(Spiele|Spiel|Starte) [das ]Album {mass_album}"
        "Album {mass_album}"
      ];
      script = {
        action = [
          {
            action = "music_assistant.play_media";
            target.entity_id = player;
            data = {
              media_id = "{{ mass_album }}";
              media_type = "album";
            };
          }
        ];
        speech.text = "Spiele Album {{ mass_album }}.";
      };
    };

    # mass_genre's `out:` is a `library://genre/<id>` URI rather than a
    # name. MA's HA integration resolves bare names via
    # get_item_by_name, which has no get_library_genres fall-through,
    # so the only path that actually plays a genre is the direct-URI
    # branch. That also means `{{ mass_genre }}` is a URI here, not a
    # human label — hence the generic speech response.
    Musik_Genre = {
      sentences = [
        "(Spiele|Spiel|Starte) {mass_genre} (Musik|Lieder)"
        "(Spiele|Spiel|Starte) [die ]Musikrichtung {mass_genre}"
        "(Genre|Musikrichtung) {mass_genre} [Musik]"
      ];
      script = {
        action = [
          {
            action = "music_assistant.play_media";
            target.entity_id = player;
            data.media_id = "{{ mass_genre }}";
          }
        ];
        speech.text = "Spiele Musik.";
      };
    };

    Musik_Kuenstler = {
      sentences = [
        "(Spiele|Spiel|Starte) [den ](Künstler|Artist) {mass_artist}"
        "(Spiele|Spiel) (was|etwas|Musik) von {mass_artist}"
        "(Künstler|Artist) {mass_artist}"
      ];
      script = {
        action = [
          {
            action = "music_assistant.play_media";
            target.entity_id = player;
            data = {
              media_id = "{{ mass_artist }}";
              media_type = "artist";
            };
          }
        ];
        speech.text = "Spiele {{ mass_artist }}.";
      };
    };

    # mass_track is populated by mass-slot-lists.service (see
    # mass_slot_lists.py); each title gets a canonical entry plus
    # in/out aliases derived from a cleanup pass (bracketed metadata
    # stripped, split on |, /, " - ", short/numeric segments dropped).
    # The resolved `out` is the exact library title MA needs to look
    # up the track unambiguously.
    Musik_Song = silent {
      sentences = [
        "(Spiele|Spiel|Starte) [das |den ](Lied|Stück|Song) {mass_track}"
        "(Lied|Song) {mass_track}"
      ];
      script = {
        action = [
          {
            action = "music_assistant.play_media";
            target.entity_id = player;
            data = {
              media_id = "{{ mass_track }}";
              media_type = "track";
            };
          }
        ];
        speech.text = "Spiele {{ mass_track }}.";
      };
    };

    # Same title, disambiguated by artist — for ASR-collision titles
    # like "Hello", "Yesterday", "Heroes". `artist` is passed alongside
    # `media_id` so MA narrows the library search to that artist's
    # catalogue before picking a match.
    Musik_SongVonKuenstler = silent {
      sentences = [
        "(Spiele|Spiel|Starte) [das ](Lied|Stück|Song) {mass_track} von {mass_artist}"
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
